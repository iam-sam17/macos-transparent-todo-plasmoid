import QtQuick
import QtQuick.Layouts
import QtQuick.Controls as QQC2
import QtQuick.LocalStorage
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // 100% Transparent Desktop Background on KDE Plasma 6 Wayland
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground
    preferredRepresentation: fullRepresentation

    Layout.minimumWidth: 310
    Layout.minimumHeight: 380
    Layout.preferredWidth: 360
    Layout.preferredHeight: 520
    width: 360
    height: 520

    // State & Configuration bindings
    property var tasksList: []
    property var categoriesList: ["All", "Personal", "Work", "Urgent"]
    property string currentStatusFilter: "all" // "all", "active", "done"
    property string currentCategory: "All"
    property int newTaskPriority: 0 // 0: None, 1: Low (!), 2: Medium (!!), 3: High (!!!)
    property string activeSubtaskParentId: ""
    property bool addingCategoryMode: false
    property string currentDateString: ""

    // Counts
    property int totalCount: 0
    property int activeCount: 0
    property int doneCount: 0

    // Priority Helpers (macOS Reminders palette)
    function priorityColor(level) {
        if (level === 3) return "#FF453A" // High - macOS Red
        if (level === 2) return "#FF9F0A" // Medium - macOS Amber/Orange
        if (level === 1) return "#0A84FF" // Low - macOS Blue
        return Qt.rgba(1, 1, 1, 0.55)
    }

    function priorityLabel(level) {
        if (level === 3) return "!!!"
        if (level === 2) return "!!"
        if (level === 1) return "!"
        return "•"
    }

    // Date Formatter matching "SATURDAY, OCTOBER 17"
    function updateDateText() {
        var now = new Date()
        var formatted = Qt.formatDate(now, "dddd, MMMM d")
        currentDateString = formatted.toUpperCase()
    }

    Timer {
        interval: 60000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: root.updateDateText()
    }

    // Local Storage (SQLite fallback + Plasmoid.configuration JSON persistence)
    function getDatabase() {
        return LocalStorage.openDatabaseSync(
            "MacOSFloatingRemindersDB",
            "1.0",
            "Local Storage for KDE Plasma 6 Floating Reminders",
            1000000
        )
    }

    function initStorage() {
        try {
            var db = getDatabase()
            db.transaction(function(tx) {
                tx.executeSql("CREATE TABLE IF NOT EXISTS kv_store (key TEXT PRIMARY KEY, value TEXT)")
            })
        } catch (e) {
            console.warn("LocalStorage init warning:", e)
        }
        loadData()
    }

    function loadData() {
        var loadedTasks = []
        var loadedCats = ["All", "Personal", "Work", "Urgent"]

        var rawTasks = Plasmoid.configuration.tasksJson
        var rawCats = Plasmoid.configuration.categoriesJson

        try {
            var db = getDatabase()
            db.readTransaction(function(tx) {
                if (!rawTasks || rawTasks === "[]" || rawTasks === "") {
                    var rsT = tx.executeSql("SELECT value FROM kv_store WHERE key = ?", ["tasksJson"])
                    if (rsT.rows.length > 0) rawTasks = rsT.rows.item(0).value
                }
                if (!rawCats || rawCats === "") {
                    var rsC = tx.executeSql("SELECT value FROM kv_store WHERE key = ?", ["categoriesJson"])
                    if (rsC.rows.length > 0) rawCats = rsC.rows.item(0).value
                }
            })
        } catch (e) {
            console.warn("LocalStorage read warning:", e)
        }

        try {
            if (rawTasks && rawTasks.length > 0) {
                var parsedT = JSON.parse(rawTasks)
                if (Array.isArray(parsedT)) loadedTasks = parsedT
            }
        } catch (e) {
            loadedTasks = []
        }

        try {
            if (rawCats && rawCats.length > 0) {
                var parsedC = JSON.parse(rawCats)
                if (Array.isArray(parsedC) && parsedC.length > 0) loadedCats = parsedC
            }
        } catch (e) {
            loadedCats = ["All", "Personal", "Work", "Urgent"]
        }

        if (loadedCats.indexOf("All") === -1) {
            loadedCats.unshift("All")
        }

        tasksList = loadedTasks
        categoriesList = loadedCats
        recalculateCounts()
    }

    function saveData() {
        var tJson = JSON.stringify(tasksList)
        var cJson = JSON.stringify(categoriesList)
        Plasmoid.configuration.tasksJson = tJson
        Plasmoid.configuration.categoriesJson = cJson

        try {
            var db = getDatabase()
            db.transaction(function(tx) {
                tx.executeSql("INSERT OR REPLACE INTO kv_store (key, value) VALUES (?, ?)", ["tasksJson", tJson])
                tx.executeSql("INSERT OR REPLACE INTO kv_store (key, value) VALUES (?, ?)", ["categoriesJson", cJson])
            })
        } catch (e) {
            console.warn("LocalStorage write warning:", e)
        }
        recalculateCounts()
    }

    function recalculateCounts() {
        var tot = 0
        var act = 0
        var dn = 0
        for (var i = 0; i < tasksList.length; i++) {
            var t = tasksList[i]
            if (currentCategory !== "All" && t.category !== currentCategory) {
                continue
            }
            tot++
            if (t.completed) dn++
            else act++
        }
        totalCount = tot
        activeCount = act
        doneCount = dn
    }

    function generateId() {
        return Date.now().toString(36) + "_" + Math.random().toString(36).substring(2, 7)
    }

    // CRUD Operations for Tasks
    function addTask(titleText) {
        var trimmed = titleText.trim()
        if (trimmed.length === 0) return

        var targetCat = (currentCategory === "All") ? "Personal" : currentCategory
        var newTask = {
            "id": generateId(),
            "title": trimmed,
            "completed": false,
            "priority": newTaskPriority,
            "category": targetCat,
            "bold": Plasmoid.configuration.fontBold,
            "italic": Plasmoid.configuration.fontItalic,
            "subtasks": [],
            "createdAt": Date.now()
        }
        var updated = tasksList.slice()
        updated.unshift(newTask)
        tasksList = updated
        saveData()
    }

    function toggleTaskCompleted(taskId) {
        var updated = tasksList.slice()
        for (var i = 0; i < updated.length; i++) {
            if (updated[i].id === taskId) {
                updated[i].completed = !updated[i].completed
                break
            }
        }
        tasksList = updated
        saveData()
    }

    function cycleTaskPriority(taskId) {
        var updated = tasksList.slice()
        for (var i = 0; i < updated.length; i++) {
            if (updated[i].id === taskId) {
                updated[i].priority = ((updated[i].priority || 0) + 1) % 4
                break
            }
        }
        tasksList = updated
        saveData()
    }

    function toggleTaskBold(taskId) {
        var updated = tasksList.slice()
        for (var i = 0; i < updated.length; i++) {
            if (updated[i].id === taskId) {
                updated[i].bold = !updated[i].bold
                break
            }
        }
        tasksList = updated
        saveData()
    }

    function toggleTaskItalic(taskId) {
        var updated = tasksList.slice()
        for (var i = 0; i < updated.length; i++) {
            if (updated[i].id === taskId) {
                updated[i].italic = !updated[i].italic
                break
            }
        }
        tasksList = updated
        saveData()
    }

    function deleteTask(taskId) {
        var updated = []
        for (var i = 0; i < tasksList.length; i++) {
            if (tasksList[i].id !== taskId) {
                updated.push(tasksList[i])
            }
        }
        if (activeSubtaskParentId === taskId) {
            activeSubtaskParentId = ""
        }
        tasksList = updated
        saveData()
    }

    // CRUD Operations for Subtasks
    function addSubtask(parentId, subTitle) {
        var trimmed = subTitle.trim()
        if (trimmed.length === 0) return

        var updated = tasksList.slice()
        for (var i = 0; i < updated.length; i++) {
            if (updated[i].id === parentId) {
                if (!Array.isArray(updated[i].subtasks)) {
                    updated[i].subtasks = []
                }
                var subList = updated[i].subtasks.slice()
                subList.push({
                    "id": generateId(),
                    "title": trimmed,
                    "completed": false,
                    "priority": 0
                })
                updated[i].subtasks = subList
                break
            }
        }
        tasksList = updated
        saveData()
    }

    function toggleSubtaskCompleted(parentId, subId) {
        var updated = tasksList.slice()
        for (var i = 0; i < updated.length; i++) {
            if (updated[i].id === parentId && Array.isArray(updated[i].subtasks)) {
                var subList = updated[i].subtasks.slice()
                for (var j = 0; j < subList.length; j++) {
                    if (subList[j].id === subId) {
                        subList[j].completed = !subList[j].completed
                        break
                    }
                }
                updated[i].subtasks = subList
                break
            }
        }
        tasksList = updated
        saveData()
    }

    function cycleSubtaskPriority(parentId, subId) {
        var updated = tasksList.slice()
        for (var i = 0; i < updated.length; i++) {
            if (updated[i].id === parentId && Array.isArray(updated[i].subtasks)) {
                var subList = updated[i].subtasks.slice()
                for (var j = 0; j < subList.length; j++) {
                    if (subList[j].id === subId) {
                        subList[j].priority = ((subList[j].priority || 0) + 1) % 4
                        break
                    }
                }
                updated[i].subtasks = subList
                break
            }
        }
        tasksList = updated
        saveData()
    }

    function deleteSubtask(parentId, subId) {
        var updated = tasksList.slice()
        for (var i = 0; i < updated.length; i++) {
            if (updated[i].id === parentId && Array.isArray(updated[i].subtasks)) {
                var subList = []
                for (var j = 0; j < updated[i].subtasks.length; j++) {
                    if (updated[i].subtasks[j].id !== subId) {
                        subList.push(updated[i].subtasks[j])
                    }
                }
                updated[i].subtasks = subList
                break
            }
        }
        tasksList = updated
        saveData()
    }

    // Categories CRUD
    function addCategory(catName) {
        var trimmed = catName.trim()
        if (trimmed.length === 0) return
        if (categoriesList.indexOf(trimmed) === -1) {
            var updated = categoriesList.slice()
            updated.push(trimmed)
            categoriesList = updated
            currentCategory = trimmed
            saveData()
        }
        addingCategoryMode = false
    }

    function removeCategory(catName) {
        if (catName === "All") return
        var updated = []
        for (var i = 0; i < categoriesList.length; i++) {
            if (categoriesList[i] !== catName) updated.push(categoriesList[i])
        }
        categoriesList = updated
        if (currentCategory === catName) currentCategory = "All"
        saveData()
    }

    function filteredTasks() {
        var result = []
        for (var i = 0; i < tasksList.length; i++) {
            var t = tasksList[i]
            if (currentCategory !== "All" && t.category !== currentCategory) continue
            if (currentStatusFilter === "active" && t.completed) continue
            if (currentStatusFilter === "done" && !t.completed) continue
            result.push(t)
        }
        if (Plasmoid.configuration.sortByPriority) {
            result.sort(function(a, b) {
                if (a.completed !== b.completed) return a.completed ? 1 : -1
                return (b.priority || 0) - (a.priority || 0)
            })
        }
        return result
    }

    Component.onCompleted: {
        updateDateText()
        initStorage()
    }

    // Full Representation (100% Transparent Floating Canvas)
    fullRepresentation: Item {
        id: fullRoot
        anchors.fill: parent

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            // 1. HEADER SECTION (Matches Screenshot: SATURDAY, OCTOBER 17 + Reminders + 0 remaining pill)
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                // Date Header
                Item {
                    Layout.fillWidth: true
                    height: Plasmoid.configuration.showDateHeader ? dateLabel.implicitHeight : 0
                    visible: Plasmoid.configuration.showDateHeader

                    // Drop Shadow Layer
                    Text {
                        visible: Plasmoid.configuration.textShadow
                        x: dateLabel.x + 1
                        y: dateLabel.y + 1
                        text: dateLabel.text
                        font: dateLabel.font
                        color: Qt.rgba(0, 0, 0, 0.75)
                    }

                    Text {
                        id: dateLabel
                        text: root.currentDateString
                        color: Plasmoid.configuration.dateAccentColor || "#38BDF8"
                        font.family: Plasmoid.configuration.fontFamily || "Sans Serif"
                        font.pixelSize: 11
                        font.weight: Font.Bold
                        font.letterSpacing: 1.4
                    }
                }

                // Title + '+' Add Button + Remaining Badge Row
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Item {
                        Layout.fillWidth: true
                        implicitHeight: titleText.implicitHeight

                        Text {
                            visible: Plasmoid.configuration.textShadow
                            x: titleText.x + 1
                            y: titleText.y + 2
                            text: titleText.text
                            font: titleText.font
                            color: Qt.rgba(0, 0, 0, 0.72)
                        }

                        Text {
                            id: titleText
                            text: Plasmoid.configuration.widgetTitle || "Reminders"
                            color: Plasmoid.configuration.textColor || "#FFFFFF"
                            font.family: Plasmoid.configuration.fontFamily || "Sans Serif"
                            font.pixelSize: 28
                            font.weight: Font.Bold
                        }
                    }

                    // Quick '+' Button in Header (Click to focus bottom input field directly)
                    Rectangle {
                        width: 26
                        height: 26
                        radius: 13
                        color: quickAddTap.pressed ? Qt.rgba(1, 1, 1, 0.30) : (quickAddHover.hovered ? Qt.rgba(1, 1, 1, 0.22) : Qt.rgba(1, 1, 1, 0.10))
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.25)

                        HoverHandler {
                            id: quickAddHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            id: quickAddTap
                            onTapped: newTaskInput.forceActiveFocus()
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "+"
                            color: "#FFFFFF"
                            font.pixelSize: 16
                            font.bold: true
                        }
                    }

                    // "0 remaining" macOS Glass Pill Badge
                    Rectangle {
                        id: remainingPill
                        implicitWidth: remainingText.implicitWidth + 20
                        implicitHeight: 26
                        radius: 13
                        color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.25)

                        Text {
                            id: remainingText
                            anchors.centerIn: parent
                            text: root.activeCount + " remaining"
                            color: Qt.rgba(1, 1, 1, 0.90)
                            font.family: Plasmoid.configuration.fontFamily || "Sans Serif"
                            font.pixelSize: 12
                            font.weight: Font.Medium
                        }
                    }
                }
            }

            // 2. FILTER TABS & CATEGORY / FONT TOOLBAR (Matches Screenshot: All (0) | Active (0) | Done (0))
            ColumnLayout {
                id: filterTabsSection
                Layout.fillWidth: true
                spacing: 8

                // Segmented Status Filter Bar: All (0) | Active (0) | Done (0)
                Rectangle {
                    Layout.fillWidth: true
                    height: 36
                    radius: 18
                    color: Qt.rgba(1, 1, 1, 0.06)
                    border.width: 1
                    border.color: Qt.rgba(1, 1, 1, 0.22)

                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 3
                        spacing: 4

                        Repeater {
                            model: [
                                { key: "all", label: "All (" + root.totalCount + ")" },
                                { key: "active", label: "Active (" + root.activeCount + ")" },
                                { key: "done", label: "Done (" + root.doneCount + ")" }
                            ]

                            delegate: Rectangle {
                                id: statusTabPill
                                Layout.fillWidth: true
                                Layout.fillHeight: true
                                radius: 15
                                readonly property bool isSelected: root.currentStatusFilter === modelData.key
                                color: isSelected ? Qt.rgba(1, 1, 1, 0.22) : (tabHover.hovered ? Qt.rgba(1, 1, 1, 0.08) : "transparent")

                                Behavior on color {
                                    ColorAnimation { duration: 150 }
                                }

                                HoverHandler {
                                    id: tabHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: root.currentStatusFilter = modelData.key
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.label
                                    color: statusTabPill.isSelected ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.78)
                                    font.family: Plasmoid.configuration.fontFamily || "Sans Serif"
                                    font.pixelSize: 12
                                    font.weight: statusTabPill.isSelected ? Font.DemiBold : Font.Normal
                                }
                            }
                        }
                    }
                }

                // Category Tabs + Bold/Italic Quick Font Bar
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 6

                    // Scrollable Category Pills
                    Flickable {
                        Layout.fillWidth: true
                        height: 26
                        contentWidth: catRow.implicitWidth
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        RowLayout {
                            id: catRow
                            height: parent.height
                            spacing: 5

                            Repeater {
                                model: root.categoriesList

                                delegate: Rectangle {
                                    id: catPill
                                    readonly property bool isCatSelected: root.currentCategory === modelData
                                    implicitWidth: catLabel.implicitWidth + (modelData !== "All" && isCatSelected ? 26 : 16)
                                    height: 24
                                    radius: 12
                                    color: isCatSelected ? Qt.rgba(0.22, 0.74, 0.97, 0.28) : (catHover.hovered ? Qt.rgba(1, 1, 1, 0.12) : Qt.rgba(1, 1, 1, 0.05))
                                    border.width: 1
                                    border.color: isCatSelected ? (Plasmoid.configuration.dateAccentColor || "#38BDF8") : Qt.rgba(1, 1, 1, 0.18)

                                    HoverHandler {
                                        id: catHover
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        onTapped: {
                                            root.currentCategory = modelData
                                            root.recalculateCounts()
                                        }
                                    }

                                    RowLayout {
                                        anchors.centerIn: parent
                                        spacing: 4

                                        Text {
                                            id: catLabel
                                            text: modelData
                                            color: catPill.isCatSelected ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.80)
                                            font.family: Plasmoid.configuration.fontFamily || "Sans Serif"
                                            font.pixelSize: 11
                                            font.weight: catPill.isCatSelected ? Font.DemiBold : Font.Normal
                                        }

                                        // Delete custom category button when selected
                                        Text {
                                            visible: modelData !== "All" && catPill.isCatSelected
                                            text: "×"
                                            color: Qt.rgba(1, 1, 1, 0.75)
                                            font.pixelSize: 12
                                            font.bold: true

                                            TapHandler {
                                                onTapped: root.removeCategory(modelData)
                                            }
                                        }
                                    }
                                }
                            }

                            // Add Category Button or Inline Field
                            Rectangle {
                                visible: !root.addingCategoryMode
                                width: 24
                                height: 24
                                radius: 12
                                color: addCatHover.hovered ? Qt.rgba(1, 1, 1, 0.18) : Qt.rgba(1, 1, 1, 0.06)
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.20)

                                HoverHandler {
                                    id: addCatHover
                                    cursorShape: Qt.PointingHandCursor
                                }

                                TapHandler {
                                    onTapped: {
                                        root.addingCategoryMode = true
                                        newCategoryInput.forceActiveFocus()
                                    }
                                }

                                Text {
                                    anchors.centerIn: parent
                                    text: "+"
                                    color: "#FFFFFF"
                                    font.pixelSize: 13
                                }
                            }

                            Rectangle {
                                visible: root.addingCategoryMode
                                width: 96
                                height: 24
                                radius: 12
                                color: Qt.rgba(0, 0, 0, 0.35)
                                border.width: 1
                                border.color: Plasmoid.configuration.dateAccentColor || "#38BDF8"

                                TextInput {
                                    id: newCategoryInput
                                    anchors.fill: parent
                                    anchors.leftMargin: 8
                                    anchors.rightMargin: 8
                                    verticalAlignment: TextInput.AlignVCenter
                                    color: "#FFFFFF"
                                    font.pixelSize: 11
                                    clip: true
                                    onAccepted: {
                                        root.addCategory(text)
                                        text = ""
                                    }
                                    Keys.onEscapePressed: {
                                        text = ""
                                        root.addingCategoryMode = false
                                    }
                                }
                            }
                        }
                    }

                    // Global Bold (B) & Italic (I) Quick Toggles
                    RowLayout {
                        spacing: 4

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: Plasmoid.configuration.fontBold ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: Plasmoid.configuration.fontBold ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.20)

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: Plasmoid.configuration.fontBold = !Plasmoid.configuration.fontBold
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "B"
                                color: "#FFFFFF"
                                font.pixelSize: 11
                                font.bold: true
                            }
                        }

                        Rectangle {
                            width: 24
                            height: 24
                            radius: 12
                            color: Plasmoid.configuration.fontItalic ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.06)
                            border.width: 1
                            border.color: Plasmoid.configuration.fontItalic ? "#FFFFFF" : Qt.rgba(1, 1, 1, 0.20)

                            HoverHandler {
                                cursorShape: Qt.PointingHandCursor
                            }

                            TapHandler {
                                onTapped: Plasmoid.configuration.fontItalic = !Plasmoid.configuration.fontItalic
                            }

                            Text {
                                anchors.centerIn: parent
                                text: "I"
                                color: "#FFFFFF"
                                font.pixelSize: 11
                                font.italic: true
                                font.family: "Serif"
                            }
                        }
                    }
                }
            }

            // 3. FLOATING TASKS AREA (100% Transparent over Wallpaper)
            Item {
                id: tasksContainer
                Layout.fillWidth: true
                Layout.fillHeight: true

                readonly property var visibleTaskItems: root.filteredTasks()

                // Empty State (Matches Screenshot: 📝 + "No reminders yet. Add one below!")
                Item {
                    anchors.fill: parent
                    visible: tasksContainer.visibleTaskItems.length === 0

                    TapHandler {
                        onTapped: newTaskInput.forceActiveFocus()
                    }

                    HoverHandler {
                        cursorShape: Qt.PointingHandCursor
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: 10

                        Text {
                            Layout.alignment: Qt.AlignHCenter
                            text: "📝"
                            font.pixelSize: 38
                        }

                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            implicitWidth: emptyText.implicitWidth
                            implicitHeight: emptyText.implicitHeight

                            Text {
                                visible: Plasmoid.configuration.textShadow
                                x: emptyText.x + 1
                                y: emptyText.y + 1
                                text: emptyText.text
                                font: emptyText.font
                                color: Qt.rgba(0, 0, 0, 0.72)
                            }

                            Text {
                                id: emptyText
                                text: "No reminders yet. Add one below!"
                                color: Qt.rgba(1, 1, 1, 0.72)
                                font.family: Plasmoid.configuration.fontFamily || "Sans Serif"
                                font.pixelSize: 14
                                font.italic: true
                            }
                        }
                    }
                }

                // Scrollable Floating Task List
                ListView {
                    id: taskListView
                    anchors.fill: parent
                    clip: true
                    spacing: 8
                    visible: tasksContainer.visibleTaskItems.length > 0
                    model: tasksContainer.visibleTaskItems

                    delegate: Item {
                        id: taskDelegate
                        width: taskListView.width
                        implicitHeight: taskColumn.implicitHeight + 8

                        readonly property var taskObj: modelData

                        // Native Qt Quick 6 HoverHandler on the whole delegate item.
                        // Non-exclusive, never flickers or drops hover when interacting with child buttons!
                        HoverHandler {
                            id: delegateHover
                        }

                        // The task actions remain solidly active either when hovered OR when subtask input is active
                        readonly property bool isTaskActive: delegateHover.hovered || (root.activeSubtaskParentId === taskDelegate.taskObj.id)

                        // Subtle translucent hover highlight
                        Rectangle {
                            anchors.fill: parent
                            radius: 12
                            color: taskDelegate.isTaskActive ? Qt.rgba(1, 1, 1, 0.06) : "transparent"
                            border.width: taskDelegate.isTaskActive ? 1 : 0
                            border.color: Qt.rgba(1, 1, 1, 0.14)

                            Behavior on color {
                                ColorAnimation { duration: 120 }
                            }
                        }

                        ColumnLayout {
                            id: taskColumn
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.top: parent.top
                            anchors.margins: 4
                            spacing: 4

                            // Main Task Row
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 10

                                // macOS Circular Checkbox (Colored by Priority)
                                Rectangle {
                                    width: 20
                                    height: 20
                                    radius: 10
                                    color: taskDelegate.taskObj.completed ? root.priorityColor(taskDelegate.taskObj.priority || 0) : "transparent"
                                    border.width: 2
                                    border.color: root.priorityColor(taskDelegate.taskObj.priority || 0)

                                    HoverHandler {
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        onTapped: root.toggleTaskCompleted(taskDelegate.taskObj.id)
                                    }

                                    Rectangle {
                                        visible: taskDelegate.taskObj.completed
                                        width: 8
                                        height: 8
                                        radius: 4
                                        anchors.centerIn: parent
                                        color: "#FFFFFF"
                                    }
                                }

                                // Priority Flag Badge (!, !!, !!!)
                                Rectangle {
                                    visible: (taskDelegate.taskObj.priority || 0) > 0 || taskDelegate.isTaskActive
                                    implicitWidth: prioText.implicitWidth + 10
                                    height: 18
                                    radius: 9
                                    color: (taskDelegate.taskObj.priority || 0) > 0 ? Qt.rgba(0, 0, 0, 0.32) : Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1
                                    border.color: root.priorityColor(taskDelegate.taskObj.priority || 0)

                                    HoverHandler {
                                        cursorShape: Qt.PointingHandCursor
                                    }

                                    TapHandler {
                                        onTapped: root.cycleTaskPriority(taskDelegate.taskObj.id)
                                    }

                                    Text {
                                        id: prioText
                                        anchors.centerIn: parent
                                        text: root.priorityLabel(taskDelegate.taskObj.priority || 0)
                                        color: root.priorityColor(taskDelegate.taskObj.priority || 0)
                                        font.pixelSize: 10
                                        font.bold: true
                                    }
                                }

                                // Floating Task Title (100% Transparent with Wallpaper Drop Shadow + Bold/Italic)
                                Item {
                                    Layout.fillWidth: true
                                    implicitHeight: mainTaskTitle.implicitHeight

                                    Text {
                                        visible: Plasmoid.configuration.textShadow
                                        width: parent.width
                                        x: mainTaskTitle.x + 1
                                        y: mainTaskTitle.y + 1
                                        text: mainTaskTitle.text
                                        font: mainTaskTitle.font
                                        wrapMode: Text.WordWrap
                                        color: Qt.rgba(0, 0, 0, 0.80)
                                    }

                                    Text {
                                        id: mainTaskTitle
                                        width: parent.width
                                        text: taskDelegate.taskObj.title
                                        wrapMode: Text.WordWrap
                                        color: taskDelegate.taskObj.completed ? Qt.rgba(1, 1, 1, 0.48) : (Plasmoid.configuration.textColor || "#FFFFFF")
                                        font.family: Plasmoid.configuration.fontFamily || "Sans Serif"
                                        font.pixelSize: Plasmoid.configuration.fontSize || 15
                                        font.bold: (taskDelegate.taskObj.bold !== undefined ? taskDelegate.taskObj.bold : false) || Plasmoid.configuration.fontBold
                                        font.italic: (taskDelegate.taskObj.italic !== undefined ? taskDelegate.taskObj.italic : false) || Plasmoid.configuration.fontItalic
                                        font.strikeout: taskDelegate.taskObj.completed
                                    }
                                }

                                // Category Tag Pill (subtle)
                                Rectangle {
                                    visible: root.currentCategory === "All" && taskDelegate.taskObj.category && taskDelegate.taskObj.category !== "All"
                                    implicitWidth: catTagText.implicitWidth + 10
                                    height: 18
                                    radius: 9
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.16)

                                    Text {
                                        id: catTagText
                                        anchors.centerIn: parent
                                        text: taskDelegate.taskObj.category
                                        color: Qt.rgba(1, 1, 1, 0.72)
                                        font.pixelSize: 10
                                    }
                                }

                                // Hover Action Buttons: Bold (B), Italic (I), Add Subtask (+), Delete (×)
                                // Completely glitch-free with TapHandler & individual hover tracking
                                RowLayout {
                                    spacing: 4
                                    opacity: taskDelegate.isTaskActive ? 1.0 : 0.0
                                    visible: opacity > 0.01

                                    Behavior on opacity {
                                        NumberAnimation { duration: 120 }
                                    }

                                    // Per-task Bold Toggle
                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: taskDelegate.taskObj.bold ? Qt.rgba(1, 1, 1, 0.28) : (btnBoldHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.22)

                                        HoverHandler {
                                            id: btnBoldHover
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        TapHandler {
                                            onTapped: root.toggleTaskBold(taskDelegate.taskObj.id)
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "B"
                                            color: "#FFFFFF"
                                            font.pixelSize: 10
                                            font.bold: true
                                        }
                                    }

                                    // Per-task Italic Toggle
                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: taskDelegate.taskObj.italic ? Qt.rgba(1, 1, 1, 0.28) : (btnItalicHover.hovered ? Qt.rgba(1, 1, 1, 0.16) : Qt.rgba(1, 1, 1, 0.08))
                                        border.width: 1
                                        border.color: Qt.rgba(1, 1, 1, 0.22)

                                        HoverHandler {
                                            id: btnItalicHover
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        TapHandler {
                                            onTapped: root.toggleTaskItalic(taskDelegate.taskObj.id)
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "I"
                                            color: "#FFFFFF"
                                            font.pixelSize: 10
                                            font.italic: true
                                            font.family: "Serif"
                                        }
                                    }

                                    // Add Subtask Button (+)
                                    Rectangle {
                                        id: subtaskToggleBtn
                                        width: 20
                                        height: 20
                                        radius: 10
                                        readonly property bool isSubtaskOpen: root.activeSubtaskParentId === taskDelegate.taskObj.id
                                        color: isSubtaskOpen ? Qt.rgba(0.22, 0.74, 0.97, 0.40) : (btnSubHover.hovered ? Qt.rgba(0.22, 0.74, 0.97, 0.25) : Qt.rgba(1, 1, 1, 0.10))
                                        border.width: 1
                                        border.color: isSubtaskOpen ? (Plasmoid.configuration.dateAccentColor || "#38BDF8") : Qt.rgba(1, 1, 1, 0.24)

                                        HoverHandler {
                                            id: btnSubHover
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        TapHandler {
                                            onTapped: {
                                                if (root.activeSubtaskParentId === taskDelegate.taskObj.id) {
                                                    root.activeSubtaskParentId = ""
                                                } else {
                                                    root.activeSubtaskParentId = taskDelegate.taskObj.id
                                                }
                                            }
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: subtaskToggleBtn.isSubtaskOpen ? "−" : "+"
                                            color: "#FFFFFF"
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                    }

                                    // Delete Task Button (×)
                                    Rectangle {
                                        width: 20
                                        height: 20
                                        radius: 10
                                        color: btnDelTap.pressed ? Qt.rgba(1, 0.27, 0.23, 0.65) : (btnDelHover.hovered ? Qt.rgba(1, 0.27, 0.23, 0.45) : Qt.rgba(1, 1, 1, 0.10))
                                        border.width: 1
                                        border.color: btnDelHover.hovered ? "#FF453A" : Qt.rgba(1, 1, 1, 0.24)

                                        HoverHandler {
                                            id: btnDelHover
                                            cursorShape: Qt.PointingHandCursor
                                        }

                                        TapHandler {
                                            id: btnDelTap
                                            onTapped: root.deleteTask(taskDelegate.taskObj.id)
                                        }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "×"
                                            color: "#FFFFFF"
                                            font.pixelSize: 13
                                            font.bold: true
                                        }
                                    }
                                }
                            }

                            // Subtasks List (Indented under Parent Task)
                            ColumnLayout {
                                Layout.fillWidth: true
                                Layout.leftMargin: 28
                                spacing: 4
                                visible: (Array.isArray(taskDelegate.taskObj.subtasks) && taskDelegate.taskObj.subtasks.length > 0) || (root.activeSubtaskParentId === taskDelegate.taskObj.id)

                                Repeater {
                                    model: Array.isArray(taskDelegate.taskObj.subtasks) ? taskDelegate.taskObj.subtasks : []

                                    delegate: RowLayout {
                                        id: subRow
                                        Layout.fillWidth: true
                                        spacing: 8

                                        HoverHandler {
                                            id: subRowHover
                                        }

                                        // Subtask Checkbox
                                        Rectangle {
                                            width: 15
                                            height: 15
                                            radius: 8
                                            color: modelData.completed ? root.priorityColor(modelData.priority || 0) : "transparent"
                                            border.width: 1.5
                                            border.color: root.priorityColor(modelData.priority || 0)

                                            HoverHandler {
                                                cursorShape: Qt.PointingHandCursor
                                            }

                                            TapHandler {
                                                onTapped: root.toggleSubtaskCompleted(taskDelegate.taskObj.id, modelData.id)
                                            }

                                            Rectangle {
                                                visible: modelData.completed
                                                width: 6
                                                height: 6
                                                radius: 3
                                                anchors.centerIn: parent
                                                color: "#FFFFFF"
                                            }
                                        }

                                        // Subtask Priority cycle badge
                                        Rectangle {
                                            visible: (modelData.priority || 0) > 0 || taskDelegate.isTaskActive
                                            implicitWidth: subPrioText.implicitWidth + 8
                                            height: 15
                                            radius: 7
                                            color: Qt.rgba(0, 0, 0, 0.28)
                                            border.width: 1
                                            border.color: root.priorityColor(modelData.priority || 0)

                                            HoverHandler {
                                                cursorShape: Qt.PointingHandCursor
                                            }

                                            TapHandler {
                                                onTapped: root.cycleSubtaskPriority(taskDelegate.taskObj.id, modelData.id)
                                            }

                                            Text {
                                                id: subPrioText
                                                anchors.centerIn: parent
                                                text: root.priorityLabel(modelData.priority || 0)
                                                color: root.priorityColor(modelData.priority || 0)
                                                font.pixelSize: 9
                                                font.bold: true
                                            }
                                        }

                                        // Floating Subtask Text
                                        Item {
                                            Layout.fillWidth: true
                                            implicitHeight: subTitleText.implicitHeight

                                            Text {
                                                visible: Plasmoid.configuration.textShadow
                                                width: parent.width
                                                x: subTitleText.x + 1
                                                y: subTitleText.y + 1
                                                text: subTitleText.text
                                                font: subTitleText.font
                                                wrapMode: Text.WordWrap
                                                color: Qt.rgba(0, 0, 0, 0.78)
                                            }

                                            Text {
                                                id: subTitleText
                                                width: parent.width
                                                text: modelData.title
                                                wrapMode: Text.WordWrap
                                                color: modelData.completed ? Qt.rgba(1, 1, 1, 0.45) : Qt.rgba(1, 1, 1, 0.88)
                                                font.family: Plasmoid.configuration.fontFamily || "Sans Serif"
                                                font.pixelSize: Math.max(11, (Plasmoid.configuration.fontSize || 15) - 2)
                                                font.bold: (taskDelegate.taskObj.bold !== undefined ? taskDelegate.taskObj.bold : false) || Plasmoid.configuration.fontBold
                                                font.italic: (taskDelegate.taskObj.italic !== undefined ? taskDelegate.taskObj.italic : false) || Plasmoid.configuration.fontItalic
                                                font.strikeout: modelData.completed
                                            }
                                        }

                                        // Delete Subtask Button (Visible on Hover)
                                        Rectangle {
                                            visible: subRowHover.hovered || taskDelegate.isTaskActive
                                            width: 16
                                            height: 16
                                            radius: 8
                                            color: subDelHover.hovered ? Qt.rgba(1, 0.27, 0.23, 0.45) : Qt.rgba(1, 1, 1, 0.08)

                                            HoverHandler {
                                                id: subDelHover
                                                cursorShape: Qt.PointingHandCursor
                                            }

                                            TapHandler {
                                                onTapped: root.deleteSubtask(taskDelegate.taskObj.id, modelData.id)
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "×"
                                                color: Qt.rgba(1, 1, 1, 0.75)
                                                font.pixelSize: 11
                                            }
                                        }
                                    }
                                }

                                // Inline "+ Add subtask..." Input Box
                                Rectangle {
                                    visible: root.activeSubtaskParentId === taskDelegate.taskObj.id
                                    Layout.fillWidth: true
                                    height: 28
                                    radius: 14
                                    color: Qt.rgba(1, 1, 1, 0.08)
                                    border.width: 1
                                    border.color: Qt.rgba(1, 1, 1, 0.25)

                                    RowLayout {
                                        anchors.fill: parent
                                        anchors.leftMargin: 10
                                        anchors.rightMargin: 4
                                        spacing: 6

                                        Item {
                                            Layout.fillWidth: true
                                            Layout.fillHeight: true

                                            Text {
                                                anchors.verticalCenter: parent.verticalCenter
                                                visible: subtaskField.text.length === 0
                                                text: "+ Add subtask..."
                                                color: Qt.rgba(1, 1, 1, 0.50)
                                                font.pixelSize: 12
                                                font.italic: true
                                            }

                                            TextInput {
                                                id: subtaskField
                                                anchors.fill: parent
                                                verticalAlignment: TextInput.AlignVCenter
                                                color: "#FFFFFF"
                                                font.family: Plasmoid.configuration.fontFamily || "Sans Serif"
                                                font.pixelSize: 12
                                                clip: true
                                                Component.onCompleted: {
                                                    if (visible) forceActiveFocus()
                                                }
                                                onVisibleChanged: {
                                                    if (visible) forceActiveFocus()
                                                }
                                                onAccepted: {
                                                    if (text.trim().length > 0) {
                                                        root.addSubtask(taskDelegate.taskObj.id, text)
                                                        text = ""
                                                    }
                                                }
                                                Keys.onEscapePressed: {
                                                    text = ""
                                                    root.activeSubtaskParentId = ""
                                                }
                                            }
                                        }

                                        Rectangle {
                                            width: 20
                                            height: 20
                                            radius: 10
                                            color: subSubmitHover.hovered ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.18)

                                            HoverHandler {
                                                id: subSubmitHover
                                                cursorShape: Qt.PointingHandCursor
                                            }

                                            TapHandler {
                                                onTapped: {
                                                    if (subtaskField.text.trim().length > 0) {
                                                        root.addSubtask(taskDelegate.taskObj.id, subtaskField.text)
                                                        subtaskField.text = ""
                                                    }
                                                }
                                            }

                                            Text {
                                                anchors.centerIn: parent
                                                text: "↑"
                                                color: "#FFFFFF"
                                                font.pixelSize: 11
                                                font.bold: true
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // 4. BOTTOM INPUT BOX (Matches Screenshot: macOS pill with left priority dot, "+ Add a new reminder...", and right "↑" submit button)
            Rectangle {
                id: bottomInputBox
                Layout.fillWidth: true
                height: 48
                radius: 24
                color: Qt.rgba(1, 1, 1, 0.08)
                border.width: 1
                border.color: newTaskInput.activeFocus ? Qt.rgba(1, 1, 1, 0.55) : Qt.rgba(1, 1, 1, 0.28)

                TapHandler {
                    onTapped: newTaskInput.forceActiveFocus()
                }

                HoverHandler {
                    cursorShape: Qt.IBeamCursor
                }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 10
                    spacing: 10

                    // Left Circular Priority Selector Button (Matches screenshot's dot icon)
                    Rectangle {
                        id: priorityCycleButton
                        width: 28
                        height: 28
                        radius: 14
                        color: Qt.rgba(1, 1, 1, 0.12)
                        border.width: 1.5
                        border.color: root.newTaskPriority > 0 ? root.priorityColor(root.newTaskPriority) : Qt.rgba(1, 1, 1, 0.30)

                        HoverHandler {
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            onTapped: {
                                root.newTaskPriority = (root.newTaskPriority + 1) % 4
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: root.priorityLabel(root.newTaskPriority)
                            color: root.newTaskPriority > 0 ? root.priorityColor(root.newTaskPriority) : "#FFFFFF"
                            font.pixelSize: root.newTaskPriority > 0 ? 11 : 14
                            font.bold: true
                        }
                    }

                    // Middle Text Input ("+ Add a new reminder...")
                    Item {
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            visible: newTaskInput.text.length === 0
                            text: "+ Add a new reminder..."
                            color: Qt.rgba(1, 1, 1, 0.55)
                            font.family: Plasmoid.configuration.fontFamily || "Sans Serif"
                            font.pixelSize: 14
                            font.italic: true
                        }

                        TextInput {
                            id: newTaskInput
                            anchors.fill: parent
                            verticalAlignment: TextInput.AlignVCenter
                            color: "#FFFFFF"
                            font.family: Plasmoid.configuration.fontFamily || "Sans Serif"
                            font.pixelSize: 14
                            font.bold: Plasmoid.configuration.fontBold
                            font.italic: Plasmoid.configuration.fontItalic
                            clip: true
                            selectByMouse: true

                            onAccepted: {
                                if (text.trim().length > 0) {
                                    root.addTask(text)
                                    text = ""
                                }
                            }
                        }
                    }

                    // Right Circular Submit Button ("↑")
                    Rectangle {
                        width: 32
                        height: 32
                        radius: 16
                        color: submitTap.pressed ? Qt.rgba(1, 1, 1, 0.35) : (submitHover.hovered ? Qt.rgba(1, 1, 1, 0.28) : Qt.rgba(1, 1, 1, 0.16))
                        border.width: 1
                        border.color: Qt.rgba(1, 1, 1, 0.30)

                        HoverHandler {
                            id: submitHover
                            cursorShape: Qt.PointingHandCursor
                        }

                        TapHandler {
                            id: submitTap
                            onTapped: {
                                if (newTaskInput.text.trim().length > 0) {
                                    root.addTask(newTaskInput.text)
                                    newTaskInput.text = ""
                                } else {
                                    newTaskInput.forceActiveFocus()
                                }
                            }
                        }

                        Text {
                            anchors.centerIn: parent
                            text: "↑"
                            color: "#FFFFFF"
                            font.pixelSize: 15
                            font.bold: true
                        }
                    }
                }
            }
        }
    }
}
