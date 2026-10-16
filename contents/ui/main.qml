import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.LocalStorage
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "Storage.js" as Storage

PlasmoidItem {
    id: root

    // 100% Transparent: NoBackground turns off default plasma panel/card frame
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    preferredRepresentation: fullRepresentation

    width: 340
    height: 520
    Layout.minimumWidth: 280
    Layout.minimumHeight: 360
    Layout.preferredWidth: 340
    Layout.preferredHeight: 520

    property string widgetTitle: (Plasmoid.configuration && Plasmoid.configuration.widgetTitle) ? Plasmoid.configuration.widgetTitle : "Reminders"
    property string currentFilter: (Plasmoid.configuration && Plasmoid.configuration.filterMode) ? Plasmoid.configuration.filterMode : "all"
    property string newPriority: "none" // none, low, med, high

    fullRepresentation: Item {
        id: mainContainer
        anchors.fill: parent

        // 100% transparent container - text floats directly on wallpaper
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 12

            // ================= HEADER SECTION =================
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3

                // Dynamic uppercase date (macOS style)
                Text {
                    id: headerDate
                    text: Qt.formatDateTime(new Date(), "dddd, MMMM d").toUpperCase()
                    font.pixelSize: 11
                    font.weight: Font.DemiBold
                    font.letterSpacing: 1.2
                    color: "#64D2FF" // macOS accent cyan
                    style: Text.DropShadow
                    styleColor: Qt.rgba(0, 0, 0, 0.85)
                }

                // Title & Active Tasks Badge
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    Text {
                        text: root.widgetTitle
                        font.pixelSize: 22
                        font.weight: Font.Bold
                        color: "#FFFFFF"
                        style: Text.DropShadow
                        styleColor: Qt.rgba(0, 0, 0, 0.9)
                        Layout.fillWidth: true
                    }

                    // Remaining tasks badge
                    Rectangle {
                        height: 22
                        width: countLabel.implicitWidth + 14
                        radius: 11
                        color: Qt.rgba(255, 255, 255, 0.14)
                        border.color: Qt.rgba(255, 255, 255, 0.22)
                        border.width: 1

                        Text {
                            id: countLabel
                            anchors.centerIn: parent
                            text: getActiveCount() + " remaining"
                            font.pixelSize: 10
                            font.weight: Font.SemiBold
                            color: "#FFFFFF"
                            style: Text.DropShadow
                            styleColor: Qt.rgba(0, 0, 0, 0.8)
                        }
                    }
                }

                // Sleek macOS Progress Bar
                Rectangle {
                    Layout.fillWidth: true
                    height: 3
                    radius: 1.5
                    color: Qt.rgba(255, 255, 255, 0.12)
                    visible: taskModel.count > 0

                    Rectangle {
                        height: parent.height
                        radius: parent.radius
                        color: "#34C759" // macOS Vibrant Green
                        width: taskModel.count > 0 ? (getCompletedCount() / taskModel.count) * parent.width : 0
                        Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutCubic } }
                    }
                }
            }

            // ================= SEGMENTED FILTER PILLS =================
            Rectangle {
                Layout.fillWidth: true
                height: 30
                radius: 15
                color: Qt.rgba(0, 0, 0, 0.22)
                border.color: Qt.rgba(255, 255, 255, 0.12)
                border.width: 1

                RowLayout {
                    anchors.fill: parent
                    spacing: 2
                    anchors.margins: 2

                    Repeater {
                        model: [
                            { key: "all", label: "All" },
                            { key: "active", label: "Active" },
                            { key: "done", label: "Done" }
                        ]

                        Rectangle {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            radius: 13
                            color: root.currentFilter === modelData.key ? Qt.rgba(255, 255, 255, 0.24) : (tabHover.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent")

                            Behavior on color { ColorAnimation { duration: 150 } }

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    var count = 0;
                                    if (modelData.key === "all") count = taskModel.count;
                                    else if (modelData.key === "active") count = getActiveCount();
                                    else count = getCompletedCount();
                                    return modelData.label + " (" + count + ")";
                                }
                                font.pixelSize: 11
                                font.weight: root.currentFilter === modelData.key ? Font.SemiBold : Font.Normal
                                color: root.currentFilter === modelData.key ? "#FFFFFF" : Qt.rgba(255, 255, 255, 0.75)
                                style: Text.DropShadow
                                styleColor: Qt.rgba(0, 0, 0, 0.8)
                            }

                            MouseArea {
                                id: tabHover
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    root.currentFilter = modelData.key;
                                    if (Plasmoid.configuration) {
                                        Plasmoid.configuration.filterMode = root.currentFilter;
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ================= TO-DO LIST VIEW =================
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true

                // Empty state notification
                ColumnLayout {
                    anchors.centerIn: parent
                    spacing: 8
                    visible: getVisibleCount() === 0

                    Text {
                        text: root.currentFilter === "done" ? "✓" : "📝"
                        font.pixelSize: 32
                        Layout.alignment: Qt.AlignHCenter
                        style: Text.DropShadow
                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                    }

                    Text {
                        text: {
                            if (root.currentFilter === "done") return "No completed tasks yet";
                            if (root.currentFilter === "active") return "All caught up! Nothing pending.";
                            return "No reminders yet. Add one below!";
                        }
                        font.pixelSize: 12
                        font.italic: true
                        color: Qt.rgba(255, 255, 255, 0.7)
                        style: Text.DropShadow
                        styleColor: Qt.rgba(0, 0, 0, 0.85)
                        Layout.alignment: Qt.AlignHCenter
                    }
                }

                ListView {
                    id: taskListView
                    anchors.fill: parent
                    clip: true
                    spacing: 4
                    model: taskModel

                    delegate: Item {
                        id: taskDelegate
                        width: taskListView.width
                        property bool isItemVisible: {
                            if (root.currentFilter === "all") return true;
                            if (root.currentFilter === "active") return !isDone;
                            if (root.currentFilter === "done") return isDone;
                            return true;
                        }

                        visible: isItemVisible
                        height: isItemVisible ? rowContainer.implicitHeight + 4 : 0
                        opacity: isItemVisible ? 1.0 : 0.0

                        Behavior on height { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
                        Behavior on opacity { NumberAnimation { duration: 160 } }

                        property bool isEditing: false

                        Rectangle {
                            id: rowContainer
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            implicitHeight: Math.max(34, contentRow.implicitHeight + 10)
                            radius: 10
                            color: rowMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.08) : "transparent"
                            border.color: rowMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.12) : "transparent"
                            border.width: 1

                            Behavior on color { ColorAnimation { duration: 120 } }

                            RowLayout {
                                id: contentRow
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: 6
                                anchors.rightMargin: 6
                                spacing: 8

                                // Circular macOS Checkbox
                                Rectangle {
                                    id: checkCircle
                                    width: 18
                                    height: 18
                                    radius: 9
                                    color: isDone ? "#007AFF" : (circleMouse.containsMouse ? Qt.rgba(255, 255, 255, 0.18) : "transparent")
                                    border.color: isDone ? "#007AFF" : (circleMouse.containsMouse ? "#FFFFFF" : Qt.rgba(255, 255, 255, 0.65))
                                    border.width: 1.5

                                    Behavior on color { ColorAnimation { duration: 150 } }
                                    Behavior on border.color { ColorAnimation { duration: 150 } }

                                    Text {
                                        anchors.centerIn: parent
                                        text: "✓"
                                        font.pixelSize: 11
                                        font.bold: true
                                        color: "#FFFFFF"
                                        visible: isDone
                                        scale: isDone ? 1.0 : 0.0
                                        Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                                    }

                                    MouseArea {
                                id: circleMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    taskModel.setProperty(index, "isDone", !isDone);
                                    saveAllState();
                                }
                            }
                                }

                                // Priority Indicator Dot
                                Rectangle {
                                    width: 6
                                    height: 6
                                    radius: 3
                                    visible: priority !== "none"
                                    color: priority === "high" ? "#FF3B30" : (priority === "med" ? "#FF9500" : "#007AFF")
                                    Layout.alignment: Qt.AlignVCenter
                                }

                                // Task Text / Inline Edit TextField
                                Item {
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    implicitHeight: taskDelegate.isEditing ? editInput.implicitHeight : taskText.implicitHeight

                                    Text {
                                        id: taskText
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: title
                                        font.pixelSize: 13
                                        font.weight: isDone ? Font.Normal : Font.Medium
                                        font.strikeout: isDone
                                        color: isDone ? Qt.rgba(255, 255, 255, 0.45) : "#FFFFFF"
                                        style: Text.DropShadow
                                        styleColor: Qt.rgba(0, 0, 0, 0.85)
                                        wrapMode: Text.Wrap
                                        visible: !taskDelegate.isEditing

                                        Behavior on color { ColorAnimation { duration: 150 } }
                                    }

                                    TextInput {
                                        id: editInput
                                        anchors.left: parent.left
                                        anchors.right: parent.right
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: title
                                        font.pixelSize: 13
                                        color: "#FFFFFF"
                                        visible: taskDelegate.isEditing
                                        selectByMouse: true

                                        onAccepted: {
                                            if (text.trim().length > 0) {
                                                taskModel.setProperty(index, "title", text.trim());
                                                saveAllState();
                                            }
                                            taskDelegate.isEditing = false;
                                        }
                                    }
                                }

                                // Hover Action Buttons (macOS Subtle Minimalist)
                                RowLayout {
                                    spacing: 4
                                    opacity: (rowMouse.containsMouse || taskDelegate.isEditing) ? 1.0 : 0.0
                                    Behavior on opacity { NumberAnimation { duration: 120 } }

                                    // Cycle priority button
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 6
                                        color: prioHover.containsMouse ? Qt.rgba(255, 255, 255, 0.2) : Qt.rgba(255, 255, 255, 0.08)

                                        Text {
                                            anchors.centerIn: parent
                                            text: priority === "high" ? "!!!" : (priority === "med" ? "!!" : (priority === "low" ? "!" : "·"))
                                            font.pixelSize: 10
                                            font.bold: true
                                            color: priority === "high" ? "#FF3B30" : (priority === "med" ? "#FF9500" : (priority === "low" ? "#007AFF" : "#FFFFFF"))
                                        }

                                        MouseArea {
                                            id: prioHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                var nextPrio = "none";
                                                if (priority === "none") nextPrio = "high";
                                                else if (priority === "high") nextPrio = "med";
                                                else if (priority === "med") nextPrio = "low";
                                                else nextPrio = "none";
                                                taskModel.setProperty(index, "priority", nextPrio);
                                                saveAllState();
                                            }
                                        }
                                    }

                                    // Inline edit toggle button
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 6
                                        color: editHover.containsMouse ? Qt.rgba(255, 255, 255, 0.2) : Qt.rgba(255, 255, 255, 0.08)

                                        Text {
                                            anchors.centerIn: parent
                                            text: taskDelegate.isEditing ? "✓" : "✎"
                                            font.pixelSize: 11
                                            color: "#FFFFFF"
                                        }

                                        MouseArea {
                                            id: editHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                if (taskDelegate.isEditing) {
                                                    if (editInput.text.trim().length > 0) {
                                                        taskModel.setProperty(index, "title", editInput.text.trim());
                                                        saveAllState();
                                                    }
                                                    taskDelegate.isEditing = false;
                                                } else {
                                                    taskDelegate.isEditing = true;
                                                    editInput.forceActiveFocus();
                                                }
                                            }
                                        }
                                    }

                                    // Delete task button
                                    Rectangle {
                                        width: 22
                                        height: 22
                                        radius: 6
                                        color: delHover.containsMouse ? Qt.rgba(255, 59, 48, 0.4) : Qt.rgba(255, 255, 255, 0.08)

                                        Behavior on color { ColorAnimation { duration: 120 } }

                                        Text {
                                            anchors.centerIn: parent
                                            text: "✕"
                                            font.pixelSize: 11
                                            color: delHover.containsMouse ? "#FF6961" : Qt.rgba(255, 255, 255, 0.8)
                                        }

                                        MouseArea {
                                            id: delHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {
                                                taskModel.remove(index);
                                                saveAllState();
                                            }
                                        }
                                    }
                                }
                            }

                            MouseArea {
                                id: rowMouse
                                anchors.fill: parent
                                hoverEnabled: true
                                propagateComposedEvents: true
                                onDoubleClicked: {
                                    taskDelegate.isEditing = true;
                                    editInput.forceActiveFocus();
                                }
                            }
                        }
                    }
                }
            }

            // ================= CLEAR COMPLETED FOOTER =================
            RowLayout {
                Layout.fillWidth: true
                visible: getCompletedCount() > 0

                Item { Layout.fillWidth: true }

                Rectangle {
                    height: 24
                    width: clearLabel.implicitWidth + 16
                    radius: 12
                    color: clearMouse.containsMouse ? Qt.rgba(255, 59, 48, 0.28) : Qt.rgba(255, 255, 255, 0.08)
                    border.color: clearMouse.containsMouse ? "#FF3B30" : Qt.rgba(255, 255, 255, 0.15)

                    Behavior on color { ColorAnimation { duration: 150 } }

                    Text {
                        id: clearLabel
                        anchors.centerIn: parent
                        text: "Clear " + getCompletedCount() + " done"
                        font.pixelSize: 11
                        font.weight: Font.Medium
                        color: clearMouse.containsMouse ? "#FF6961" : Qt.rgba(255, 255, 255, 0.75)
                        style: Text.DropShadow
                        styleColor: Qt.rgba(0, 0, 0, 0.8)
                    }

                    MouseArea {
                        id: clearMouse
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: clearCompletedTasks()
                    }
                }
            }

            // ================= QUICK ADD BAR (macOS Floating Input) =================
            Rectangle {
                Layout.fillWidth: true
                height: 42
                radius: 12
                color: Qt.rgba(0, 0, 0, 0.3)
                border.color: newTextInput.activeFocus ? "#007AFF" : Qt.rgba(255, 255, 255, 0.18)
                border.width: newTextInput.activeFocus ? 1.5 : 1

                Behavior on border.color { ColorAnimation { duration: 150 } }

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 8

                    // Quick priority toggle for new item
                    Rectangle {
                        width: 22
                        height: 22
                        radius: 11
                        color: root.newPriority === "high" ? Qt.rgba(255, 59, 48, 0.35) : (root.newPriority === "med" ? Qt.rgba(255, 149, 0, 0.35) : (root.newPriority === "low" ? Qt.rgba(0, 122, 255, 0.35) : Qt.rgba(255, 255, 255, 0.12)))
                        border.color: root.newPriority === "high" ? "#FF3B30" : (root.newPriority === "med" ? "#FF9500" : (root.newPriority === "low" ? "#007AFF" : Qt.rgba(255, 255, 255, 0.25)))

                        Text {
                            anchors.centerIn: parent
                            text: root.newPriority === "high" ? "!!!" : (root.newPriority === "med" ? "!!" : (root.newPriority === "low" ? "!" : "•"))
                            font.pixelSize: 10
                            font.bold: true
                            color: "#FFFFFF"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (root.newPriority === "none") root.newPriority = "high";
                                else if (root.newPriority === "high") root.newPriority = "med";
                                else if (root.newPriority === "med") root.newPriority = "low";
                                else root.newPriority = "none";
                            }
                        }
                    }

                    // Floating text input
                    TextInput {
                        id: newTextInput
                        Layout.fillWidth: true
                        color: "#FFFFFF"
                        font.pixelSize: 13
                        verticalAlignment: TextInput.AlignVCenter
                        clip: true

                        Text {
                            text: "+ Add a new reminder..."
                            color: Qt.rgba(255, 255, 255, 0.45)
                            font.pixelSize: 13
                            font.italic: true
                            visible: !newTextInput.text && !newTextInput.activeFocus
                            anchors.verticalCenter: parent.verticalCenter
                            style: Text.DropShadow
                            styleColor: Qt.rgba(0, 0, 0, 0.75)
                        }

                        onAccepted: addNewTask()
                    }

                    // Add action arrow button
                    Rectangle {
                        width: 28
                        height: 28
                        radius: 14
                        color: newTextInput.text.trim().length > 0 ? "#007AFF" : Qt.rgba(255, 255, 255, 0.12)

                        Behavior on color { ColorAnimation { duration: 150 } }

                        Text {
                            anchors.centerIn: parent
                            text: "↑"
                            font.pixelSize: 14
                            font.bold: true
                            color: "#FFFFFF"
                        }

                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: addNewTask()
                        }
                    }
                }
            }
        }
    }

    // ================= DATA MODEL & LOGIC =================
    ListModel {
        id: taskModel
    }

    function addNewTask() {
        var text = newTextInput.text.trim();
        if (text.length === 0) return;

        taskModel.append({
            taskId: Storage.generateId(),
            title: text,
            isDone: false,
            priority: root.newPriority,
            createdAt: Date.now()
        });

        newTextInput.text = "";
        root.newPriority = "none";
        saveAllState();
    }

    function clearCompletedTasks() {
        for (var i = taskModel.count - 1; i >= 0; i--) {
            if (taskModel.get(i).isDone) {
                taskModel.remove(i);
            }
        }
        saveAllState();
    }

    function getActiveCount() {
        var count = 0;
        for (var i = 0; i < taskModel.count; i++) {
            if (!taskModel.get(i).isDone) count++;
        }
        return count;
    }

    function getCompletedCount() {
        var count = 0;
        for (var i = 0; i < taskModel.count; i++) {
            if (taskModel.get(i).isDone) count++;
        }
        return count;
    }

    function getVisibleCount() {
        var count = 0;
        for (var i = 0; i < taskModel.count; i++) {
            var done = taskModel.get(i).isDone;
            if (root.currentFilter === "all") count++;
            else if (root.currentFilter === "active" && !done) count++;
            else if (root.currentFilter === "done" && done) count++;
        }
        return count;
    }

    function setIntroDone() {
        if (Plasmoid.configuration) {
            Plasmoid.configuration.hasCompletedIntro = true;
        }
        Storage.setSetting(LocalStorage, "hasCompletedIntro", "true");
    }

    function isIntroDone() {
        if (Plasmoid.configuration && Plasmoid.configuration.hasCompletedIntro === true) {
            return true;
        }
        if (Storage.getSetting(LocalStorage, "hasCompletedIntro", "false") === "true") {
            return true;
        }
        return false;
    }

    function saveAllState() {
        var array = [];
        for (var i = 0; i < taskModel.count; i++) {
            var item = taskModel.get(i);
            array.push({
                id: item.taskId,
                text: item.title,
                done: item.isDone,
                priority: item.priority,
                createdAt: item.createdAt
            });
        }

        saveTasksArray(array);
    }

    function saveTasksArray(array) {
        // Mark intro as completed so sample tasks never reappear
        setIntroDone();

        // 1. Native Plasma Config sync
        if (Plasmoid.configuration) {
            Plasmoid.configuration.tasksJson = JSON.stringify(array);
            Plasmoid.configuration.hasCompletedIntro = true;
        }

        // 2. SQLite local fallback sync
        Storage.saveTasks(LocalStorage, array);
    }

    function loadAllState() {
        taskModel.clear();
        var loaded = null;
        var introCompleted = isIntroDone();

        // 1. Try loading from Plasma configuration
        if (Plasmoid.configuration && typeof Plasmoid.configuration.tasksJson === "string" && Plasmoid.configuration.tasksJson.trim() !== "") {
            try {
                var parsed = JSON.parse(Plasmoid.configuration.tasksJson);
                if (Array.isArray(parsed)) {
                    loaded = parsed;
                }
            } catch (e) {
                console.warn("Failed parsing Plasmoid tasksJson", e);
            }
        }

        // 2. If Plasma config didn't have valid array, fallback to SQLite
        if (loaded === null) {
            var sqliteTasks = Storage.loadTasks(LocalStorage);
            if (Array.isArray(sqliteTasks)) {
                loaded = sqliteTasks;
            }
        }

        // 3. Handle First-Run Demo Tasks ONLY if intro was never completed
        if (!introCompleted) {
            // If user already had tasks saved in SQLite or Config from previous versions, honor them!
            if (Array.isArray(loaded) && loaded.length > 0) {
                setIntroDone();
            } else {
                // Absolute first run on a pristine system: seed the 4 sample tasks ONCE
                loaded = [
                    { id: "init_1", text: "🚀 Welcome to macOS To-Do on KDE Plasma!", done: false, priority: "high", createdAt: Date.now() - 3000 },
                    { id: "init_2", text: "✨ Click circular checkbox to complete tasks", done: false, priority: "med", createdAt: Date.now() - 2000 },
                    { id: "init_3", text: "✎ Double-click or hover to edit / delete", done: false, priority: "low", createdAt: Date.now() - 1000 },
                    { id: "init_4", text: "100% transparent floating aesthetic active", done: true, priority: "none", createdAt: Date.now() }
                ];
                saveTasksArray(loaded);
            }
        } else {
            // Intro was already done! Even if loaded is empty ([]), KEEP IT EMPTY!
            if (!Array.isArray(loaded)) {
                loaded = [];
            }
        }

        for (var i = 0; i < loaded.length; i++) {
            taskModel.append({
                taskId: loaded[i].id || Storage.generateId(),
                title: loaded[i].text || "",
                isDone: loaded[i].done === true,
                priority: loaded[i].priority || "none",
                createdAt: loaded[i].createdAt || Date.now()
            });
        }
    }

    Component.onCompleted: {
        loadAllState();
    }
}
