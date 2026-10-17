import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
    id: configRoot

    property alias cfg_widgetTitle: titleField.text
    property alias cfg_showDateHeader: showDateCheck.checked
    property alias cfg_alwaysShowInput: alwaysShowInputCheck.checked
    property string cfg_fontFamily: "Sans Serif"
    property alias cfg_fontSize: fontSizeSpin.value
    property alias cfg_fontBold: fontBoldCheck.checked
    property alias cfg_fontItalic: fontItalicCheck.checked
    property alias cfg_textShadow: textShadowCheck.checked
    property alias cfg_textColor: textColorField.text
    property alias cfg_dateAccentColor: dateColorField.text
    property alias cfg_sortByPriority: sortPriorityCheck.checked

    property string cfg_tasksJson: "[]"
    property string cfg_categoriesJson: "[]"

    Kirigami.FormLayout {
        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Header & Input Controls")
        }

        QQC2.TextField {
            id: titleField
            Kirigami.FormData.label: i18n("Widget Title:")
            placeholderText: "Reminders"
        }

        QQC2.CheckBox {
            id: showDateCheck
            Kirigami.FormData.label: i18n("Date Header:")
            text: i18n("Show uppercase date above title (e.g. SATURDAY, OCTOBER 17)")
        }

        QQC2.CheckBox {
            id: alwaysShowInputCheck
            Kirigami.FormData.label: i18n("Input Visibility:")
            text: i18n("Always show bottom input box & tabs (matches screenshot design)")
        }

        QQC2.CheckBox {
            id: sortPriorityCheck
            Kirigami.FormData.label: i18n("Task Ordering:")
            text: i18n("Automatically sort higher priority tasks to the top")
        }

        Kirigami.Separator {
            Kirigami.FormData.isSection: true
            Kirigami.FormData.label: i18n("Customizable Font & Style")
        }

        QQC2.ComboBox {
            id: fontFamilyCombo
            Kirigami.FormData.label: i18n("Font Family:")
            editable: true
            model: Qt.fontFamilies()
            onActivated: function(index) {
                configRoot.cfg_fontFamily = textAt(index)
            }
            onEditTextChanged: {
                if (editText.length > 0) {
                    configRoot.cfg_fontFamily = editText
                }
            }
            Component.onCompleted: {
                var idx = find(configRoot.cfg_fontFamily)
                if (idx >= 0) {
                    currentIndex = idx
                }
                editText = configRoot.cfg_fontFamily
            }
        }

        QQC2.SpinBox {
            id: fontSizeSpin
            Kirigami.FormData.label: i18n("Task Font Size (px):")
            from: 11
            to: 32
        }

        RowLayout {
            Kirigami.FormData.label: i18n("Font Style:")
            spacing: 16

            QQC2.CheckBox {
                id: fontBoldCheck
                text: i18n("Bold (B)")
                font.bold: true
            }

            QQC2.CheckBox {
                id: fontItalicCheck
                text: i18n("Italic (I)")
                font.italic: true
            }
        }

        QQC2.CheckBox {
            id: textShadowCheck
            Kirigami.FormData.label: i18n("Wallpaper Contrast:")
            text: i18n("Enable soft drop shadow so floating text is readable on any wallpaper")
        }

        QQC2.TextField {
            id: textColorField
            Kirigami.FormData.label: i18n("Task Text Color (Hex):")
            placeholderText: "#FFFFFF"
        }

        QQC2.TextField {
            id: dateColorField
            Kirigami.FormData.label: i18n("Date Accent Color (Hex):")
            placeholderText: "#38BDF8"
        }
    }
}
