/*
 * Copyright 2018 Roman Gilg <subdiff@gmail.com>
 * Copyright 2018 Furkan Tokac <furkantokac34@gmail.com>
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program; if not, write to the Free Software
 * Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.
 */

import QtQuick 2.7
import QtQuick.Controls 2.0 as Controls
import QtQuick.Layouts 1.3 as Layouts

import org.kde.kcm 1.1 as KCM
import org.kde.kirigami 2.4 as Kirigami

import "components"

// TODO: Change ScrollablePage as KCM.SimpleKCM
// after rewrite the KCM in KConfigModule.
Kirigami.ScrollablePage {
    id: root
    
    spacing: Kirigami.Units.smallSpacing
    
    property size sizeHint: Qt.size(formLayout.width, formLayout.height)
    property size minimumSizeHint: Qt.size(formLayout.width/2, deviceSelector.height)

    property alias deviceIndex: deviceSelector.currentIndex
    signal changeSignal()

    property QtObject device
    property int deviceCount: backend.deviceCount

    property bool loading: false

    function resetModel(index) {
        deviceCount = backend.deviceCount
        formLayout.enabled = deviceCount
        deviceSelector.enabled = deviceCount > 1

        loading = true
        if (deviceCount) {
            device = deviceModel[index]
            deviceSelector.model = deviceModel
            deviceSelector.currentIndex = index
            console.log("Configuration of device '" +
                        (index + 1) + " : " + device.name + "' opened")
        } else {
            deviceSelector.model = [""]
            console.log("No device found")
        }
        loading = false
    }

    function syncValuesFromBackend() {
        loading = true

        deviceEnabled.load()
        leftHanded.load()
        accelSpeed.load()
        accelProfile.load()
        naturalScroll.load()

        loading = false
    }

    Kirigami.FormLayout {
        id: formLayout
        enabled: deviceCount

        // Device
        Controls.ComboBox {
            Kirigami.FormData.label: i18n("Device:")
            id: deviceSelector
            enabled: deviceCount > 1
            Layouts.Layout.fillWidth: true
            model: deviceModel
            textRole: "name"

            onCurrentIndexChanged: {
                if (deviceCount) {
                    device = deviceModel[currentIndex]
                    if (!loading) {
                        changeSignal()
                    }
                    console.log("Configuration of device '" +
                                (currentIndex+1) + " : " + device.name + "' opened")
                }
                root.syncValuesFromBackend()
            }
        }

        Kirigami.Separator {
        }

        // General
        Controls.CheckBox {
            Kirigami.FormData.label: i18n("General:")
            id: deviceEnabled
            text: i18n("Device enabled")

            function load() {
                if (!formLayout.enabled) {
                    checked = false
                    return
                }
                enabled = device.supportsDisableEvents
                checked = enabled && device.enabled
            }

            onCheckedChanged: {
                if (enabled && !root.loading) {
                    device.enabled = checked
                    root.changeSignal()
                }
            }

            ToolTip {
                text: i18n("Accept input through this device.")
            }
        }

        Controls.CheckBox {
            id: leftHanded
            text: i18n("Left handed mode")

            function load() {
                if (!formLayout.enabled) {
                    checked = false
                    return
                }
                enabled = device.supportsLeftHanded
                checked = enabled && device.leftHanded
            }

            onCheckedChanged: {
                if (enabled && !root.loading) {
                    device.leftHanded = checked
                    root.changeSignal()
                }
            }

            ToolTip {
                text: i18n("Swap left and right buttons.")
            }
        }

        Controls.CheckBox {
            id: middleEmulation
            text: i18n("Press left and right buttons for middle-click")

            function load() {
                if (!formLayout.enabled) {
                    checked = false
                    return
                }
                enabled = device.supportsMiddleEmulation
                checked = enabled && device.middleEmulation
            }

            onCheckedChanged: {
                if (enabled && !root.loading) {
                    device.middleEmulation = checked
                    root.changeSignal()
                }
            }

            ToolTip {
                text: i18n("Clicking left and right button simultaneously sends middle button click.")
            }
        }

        Kirigami.Separator {
        }

        // Acceleration
        Controls.Slider {
            Kirigami.FormData.label: i18n("Pointer speed:")
            id: accelSpeed
            
            from: 1
            to: 10
            stepSize: 1

            function load() {
                enabled = device.supportsPointerAcceleration
                if (!enabled) {
                    value = 0.1
                    return
                }
                // transform libinput's pointer acceleration range [-1, 1] to slider range [1, 10]
                value = 4.5 * device.pointerAcceleration + 5.5
            }

            onValueChanged: {
                if (device != undefined && enabled && !root.loading) {
                    // transform slider range [1, 10] to libinput's pointer acceleration range [-1, 1]
                    device.pointerAcceleration = Math.round( (value - 5.5) / 4.5 * 100 ) / 100
                    root.changeSignal()
                }
            }
        }

        Layouts.ColumnLayout {
            id: accelProfile
            spacing: Kirigami.Units.smallSpacing
            Kirigami.FormData.label: i18n("Acceleration profile:")
            Kirigami.FormData.buddyFor: accelProfileFlat

            function load() {
                enabled = device.supportsPointerAccelerationProfileAdaptive

                if (!enabled) {
                    accelProfileAdaptive.checked = false
                    accelProfileFlat.checked = false
                    return
                }

                if(device.pointerAccelerationProfileAdaptive) {
                    accelProfileAdaptive.checked = true
                    accelProfileFlat.checked = false
                } else {
                    accelProfileAdaptive.checked = false
                    accelProfileFlat.checked = true
                }
            }

            function syncCurrent() {
                if (enabled && !root.loading) {
                    device.pointerAccelerationProfileFlat = accelProfileFlat.checked
                    device.pointerAccelerationProfileAdaptive = accelProfileAdaptive.checked
                    root.changeSignal()
                }
            }

            Controls.RadioButton {
                id: accelProfileFlat
                text: i18n("Flat")

                ToolTip {
                    text: i18n("Cursor moves the same distance as the mouse movement.")
                }
                onCheckedChanged: accelProfile.syncCurrent()
            }

            Controls.RadioButton {
                id: accelProfileAdaptive
                text: i18n("Adaptive")

                ToolTip {
                    text: i18n("Cursor travel distance depends on the mouse movement speed.")
                }
                onCheckedChanged: accelProfile.syncCurrent()
            }
        }

        Kirigami.Separator {
        }

        // Scrolling
        Controls.CheckBox {
            Kirigami.FormData.label: i18n("Scrolling:")
            id: naturalScroll
            text: i18n("Invert scroll direction")

            function load() {
                enabled = device.supportsNaturalScroll
                checked = enabled && device.naturalScroll
            }

            onCheckedChanged: {
                if (enabled && !root.loading) {
                    device.naturalScroll = checked
                    root.changeSignal()
                }
            }

            ToolTip {
                text: i18n("Touchscreen like scrolling.")
            }
        }
    }
}