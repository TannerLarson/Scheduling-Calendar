import QtQuick 2.13
import QtQuick.Controls 2.13
import QtQuick.Window 2.2
import QtQuick.Controls.Styles 1.4

ApplicationWindow {
    id: app
    title: qsTr("Temple Shift Organizer")
    visible: true
    height: calendar.height + cellHeight * 4
    width: calendar.width + 10
    minimumHeight: calendar.height + cellHeight * 4
    minimumWidth: calendar.width + 10

    property int cellWidth: 70
    property int cellHeight: 30
    // TODO: Allow horizontal spacing to be more than 1
    // Will have possibility of not dropping in calendar
    property int horizontalSpacing: 1
    property int verticalSpacing: 1

    property var dataDictionary: ({})
    property var workerNames: [] //["Tanner", "Jennie", "Kyle", "Rob", "Kaitlyn", "Maria"] // NAMES MUST BE UNIQUE
    property var workerLimitations: {"Tanner": {kneeling: 1, standing: 1, spanish: 1},
                                    "Jennie": {kneeling: 1, standing: 0, spanish: 1},
                                    "Kyle": {kneeling: 1, standing: 1, spanish: 0},
                                    "Rob": {kneeling: 0, standing: 1, spanish: 0},
                                    "Kaitlyn": {kneeling: 1, standing: 0, spanish: 0},
                                    "Maria": {kneeling: 0, standing: 0, spanish: 0}}
    property var positionNames: ["Position A", "Postion B", "Position C", "Position D"] // NAMES MUST BE UNIQUE
    property var positionLimitations: {"Position A": {kneeling: 1, standing: 1, spanish: 1},
                                        "Postion B": {kneeling: 1, standing: 0, spanish: 0},
                                        "Position C": {kneeling: 0, standing: 1, spanish: 0},
                                        "Position D": {kneeling: 0, standing: 0, spanish: 0}}

    property var shiftTimes: ["12:00 PM", "12:30 PM", "1:00 PM", "1:30 PM", "2:00 PM", "2:30 PM", "3:00 PM", "3:30 PM", "4:00 PM", "4:30 PM"]
    property var blackoutTiles: []
    property var calendarColumns: []

    // These four variables are used specifically to identify if a tile is inside the calendar
    property var topOfCalendar: (workerNames.length + 2) * (cellHeight + calendar.spacing) + calendar.y
    property var bottomOfCalendar: topOfCalendar + positionNames.length * (cellHeight + calendar.spacing) - calendar.spacing
    property var lSideOfCalendar: calendar.x + cellWidth + calendar.spacing
    property var rSideOfCalendar: lSideOfCalendar + shiftTimes.length * (cellWidth + calendar.spacing) - calendar.spacing


    //TODO: This signal is only used because it happens once and it happens early in the GUI creation.  A better solution is needed
    onOpenglContextCreated: {
        dataDictionary = JSON.parse(saveData.data(saveData.index(0, 0)))
        workerNames = dataDictionary["worker_names"]
        positionNames = dataDictionary["position_names"]

        var posOriginal = dataDictionary["blackout_positions"][0]
        // Delete duplicate blackout positions
        dataDictionary["blackout_positions"] = dataDictionary["blackout_positions"].sort().filter(function isSame(item, pos, arr) {
            return !pos || (item[0] !== arr[pos - 1][0] && item[1] !== arr[pos - 1][1])
        })

        // Put original blackout tile in front
        dataDictionary["blackout_positions"].sort(function(x, y) {
            return (x[0] === posOriginal[0] && x[1] === posOriginal[1]) ?
                        -1 : (y[0] === posOriginal[0] && y[1] === posOriginal[1]) ? 1 : 0;
        })

        // Create blackout tiles based on save data
        var tData = dataDictionary["blackout_positions"]
        var sprite
        for (let i = 1; i < tData.length; i++) {
            sprite = blackout.createObject(app)
            sprite.x = tData[i][0] + 1
            sprite.y = tData[i][1]
            if (sprite === null)
                console.log("Error creating blackout tile")
        }
    }

    function hotReset() {
        app.close()
        bridge.load_qml()
    }

    // positionLimits: dictionary of destined position limitations
    // workerLimits: diciionary of worker limitations
    function isPositionValid(positionLimits, workerLimits) {
        if ((positionLimits.kneeling && !workerLimits.kneeling) ||
            (positionLimits.standing && !workerLimits.standing) ||
            (positionLimits.spanish && !workerLimits.spanish))
            return 0
        else
            return 1
    }

    function save() {
        // Pick out data we want from abstract QObjects
        var calData = []
        var tileData = {}

        // Create array of [column number, [name and y position of tiles in column]]
        for (let i = 0; i < calendarColumns.length; i++) {

            // Create small array of [nameTiles.name, nameTiles.y]
            for (let j = 0; j < workerNames.length; j++) { // TODO: Don't use workerNames length
                tileData[calendarColumns[i].nameTiles[j].name] = calendarColumns[i].nameTiles[j].y
            }

            // WARNING: Make sure order of tileData is the same as column numbers
            calData.push(tileData)
            tileData = {}
        }

        // Create array of [x and y pairs of all blackout tiles]
        var bTileData = []
        for (let k = blackoutTiles.length - 1; k >= 0; k--) {
            bTileData.push([blackoutTiles[k].x, blackoutTiles[k].y])
        }

        bridge.save(JSON.stringify(workerNames),
                    JSON.stringify(positionNames),
                    JSON.stringify(bTileData),
                    JSON.stringify(calData))
    }


    Button {
        id: butAutoAssign
        anchors {
            top: calendar.bottom
            topMargin: cellHeight / 2
            right: calendar.right
        }
        text: qsTr("Auto Assign")   

        function shuffleArray(array) {
            for (let i = array.length - 1; i > 0; i--) {
                let j = Math.floor(Math.random() * (i + 1));
                [array[i], array[j]] = [array[j], array[i]];
              }
        }

        onPressed: {
            if (positionNames.length > workerNames.length) {
                console.log("Not enough workers")
                return
            }

            // Create array of names that line up correctly with position order
            console.log(calendarColumns.length)
            for (let i = 0; i < calendarColumns.length; i++) {
                var validWorkers
                var valid = []
                for (let l = 0; l < positionNames.length; l++)
                    valid.push(0)
                var positionsTemp = [...positionNames]

                while (!valid.every(function(w){return w})) {
                    // Shuffle list of workers and use beginning of list as workers to assign
                    validWorkers = [...workerNames]
                    shuffleArray(validWorkers)
                    validWorkers.splice(positionNames.length, validWorkers.length)

                    // Sort positions by requirement number
                    positionsTemp.sort(function(a,b) {
                        return (positionLimitations[b].standing + positionLimitations[b].kneeling + positionLimitations[b].spanish) -
                                (positionLimitations[a].standing + positionLimitations[a].kneeling + positionLimitations[a].spanish)
                    })

                    // Sort workers by ability number
                    validWorkers.sort(function(a,b) {
                        return (workerLimitations[b].standing + workerLimitations[b].kneeling + workerLimitations[b].spanish) -
                                (workerLimitations[a].standing + workerLimitations[a].kneeling + workerLimitations[a].spanish)
                    })


                    // Check if the workers can fill the positions.  If not, do the whole process over
                    valid.forEach(function(value){value = 0})
                    for (let j = 0; j < positionNames.length; j++) {
                        if (isPositionValid(positionLimitations[positionsTemp[j]], workerLimitations[validWorkers[j]]))
                            valid[j] = 1
                        else
                            break
                    }
                }
                console.log("workers: ", validWorkers)
                // Move workers to respective positions
                for (let k = 0; k < validWorkers.length; k++) {
                    calendarColumns[i].nameTiles.find( function(tile) {
                                                    return tile.name === validWorkers[k]
                                                }).y = topOfCalendar + positionNames.indexOf(positionNames[k]) * (cellHeight + horizontalSpacing)
                }
            }
        } // OnPressed
    }


    Button {
        id: butAddPosition
        anchors {
            top: calendar.bottom
            topMargin: cellHeight / 2
            left: calendar.left
            leftMargin: 10
        }
        text: qsTr("Add")

        onPressed: {
            if (nameInput.text !== "[Position Name]")
            {
                positionNames.push(nameInput.text)
                positionLimitations.push({key: nameInput.text,
                                          value: {kneeling: 0, standing: 0, spanish: 0}
                                         })
                save()
                hotReset()
            }
        }
    }

    Rectangle {
        id: recNameInput
        color: "lightgrey"
        anchors {
            left: butAddPosition.right
            leftMargin: 10
            top: calendar.bottom
            topMargin: cellHeight / 2
        }
        width: cellWidth * 1.5
        height: cellHeight

        TextInput {
            id: nameInput
            width: parent.width
            height: parent.height
            font.family: "Arial"
            font.pointSize: cellHeight / 3
            anchors.fill: parent
            verticalAlignment: Text.AlignVCenter
            horizontalAlignment: Text.AlignHCenter
            clip: true
            text: qsTr("[Position Name]")
        }
    }

    Button {
        id: butRemPosition
        anchors {
            top: butAddPosition.bottom
            topMargin: 10
            left: calendar.left
            leftMargin: 10
        }
        text: qsTr("Remove")

        onPressed: {
            if (cBoxPositions.currentIndex !== 0) {
                positionNames.splice(cBoxPositions.currentIndex - 1, 1)
                save()
                hotReset()
            }

        }
    }


    ComboBox {
        id: cBoxPositions
        anchors {
            top: butAddPosition.bottom
            topMargin: 10
            left: butRemPosition.right
            leftMargin: 10
        }

        model: ["[Position Name]"].concat(positionNames)
    }

    Button {
        id: reset
        anchors {
            bottom: parent.bottom
            bottomMargin: 10
            right: butSave.left
            rightMargin: verticalSpacing
        }

        text: qsTr("Reset")

        onClicked: {
            for (let i = 0; i < blackoutTiles.length; i++) {
                blackoutTiles[i].x = calendar.x + calendar.width / 2
                blackoutTiles[i].y = bottomOfCalendar + cellHeight / 2
            }
            for (let j = 0; j < calendarColumns.length; j++) {
                calendarColumns[j].sortNameTiles(1)
            }
        }
    }


    Button {
        id: butSave
        text: qsTr("Save")
        anchors {
            right: parent.right
            rightMargin: 10
            bottom: parent.bottom
            bottomMargin: 10
        }

        onClicked: save()
    }

    // Main calendar
    Row {
        id: calendar
        spacing: verticalSpacing
        anchors {
            left: app.left
            leftMargin: 10
            top: app.top
            topMargin: 10
        }

        Component {
            id: calendarColumn

            Column {
                spacing: horizontalSpacing
                width: cellWidth

                // Specify column number on calendar creation
                property int colNumber

                // This alias allows change to this property
                property alias colHeaderText: colHeaderText.text

                // Holds objects names out of calendar
                property variant nameTiles: []

                Rectangle {
                    // Header
                    width: cellWidth
                    height: cellHeight
                    Text {
                        id: colHeaderText
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        font.bold: true
                    }
                }

                Repeater {
                    // Names to drag
                    model: workerNames
                    Rectangle {
                        width: 70
                        height: 30
                        z: 10
                        color: "pink"
                        radius: 10
                        border.width: 1; border.color: "black"
                        property string name: modelData
                        Text {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            horizontalAlignment: Text.AlignHCenter
                            text: parent.name
                            font.family: "Berlin Sans FB"
                            font.pointSize: 10
                        }

                        Component.onCompleted: {
                            nameTiles.push(this)
                        }

                        // Keeps track of whether or not name has a place in calendar
                        property bool inCalendar: y > topOfCalendar - cellHeight / 1.2 &&
                                                  y < bottomOfCalendar - cellHeight / 3

                        // Draggable properties
                        property bool dragActive: dragArea.drag.active
                        onDragActiveChanged: {
                            if (dragActive) {
                                // These anchors keep the names in their respective columns
                                anchors.left = parent.left
                                anchors.right = parent.right
                                Drag.start()
                            }
                            else Drag.drop()
                        }
                        Drag.hotSpot.x: cellWidth / 2
                        Drag.hotSpot.y: cellHeight / 2
                        Drag.dragType: Drag.Automatic
                        MouseArea {
                            id: dragArea
                            anchors.fill: parent
                            drag.target: parent
                            onReleased: if (!inCalendar) sortNameTiles()
                        }
                    } //Rectangle
                }//Repeater

                // Empty rectangle for spacing
                Rectangle {
                    width: cellWidth
                    height: cellHeight
                }

                Repeater {
                    // Drag positions
                    model: positionNames
                    DropArea {
                        width: cellWidth
                        height: cellHeight

                        Rectangle {
                            width: parent.width
                            height: parent.height
                            color: "lightgrey"
                        }

                        onDropped: {
                            // Check if worker can work this position
                            if (isPositionValid(positionLimitations[modelData], workerLimitations[drag.source.name])) {
                                drag.source.y = 0
                                sortNameTiles()
                                dialogError.open("Hello")
                                return
                            }

                            if (drag.source.z === 20) { // TODO: This check for a blackout cell shouldn't be hardcoded
                                drag.source.y = y + calendar.y
                            }
                            else if (!spaceFilled(y)) {
                                drag.source.y = 0 // Put tile outside calendar so we can sort it
                                sortNameTiles()
                            }
                            else
                                drag.source.y = y
                        }
                    }
                } //Repeater

                function spaceFilled(yPosition) {
                    for (let i = 0; i < nameTiles.length; i++) {
                        if (nameTiles[i].y === yPosition)
                            return 0
                    }
                    // Space is not filled if we get to this point
                    return 1
                }

                function sortNameTiles(reset) {
                    // Sort tile names alphabetically
                    nameTiles.sort(function (a,b) {
                        if (a.name >= b.name) return 1
                        else return -1
                    })

                    // Place name in order
                    for (let i = 0; i < nameTiles.length; i++) {
                        if (reset || !nameTiles[i].inCalendar)
                            nameTiles[i].y = (i + 1) * (cellHeight + horizontalSpacing)
                    }
                }
                onPositioningComplete: {
                    //calendarColumns.push(this)
                    sortNameTiles()
                }
            } //Column
        } //Component

        // Position row headers
        Column {
            spacing: horizontalSpacing
            width: cellWidth
            height: cellHeight
            Repeater {
                model: workerNames.length + 1
                Rectangle {
                    width: cellWidth
                    height: cellHeight
                }
            }

            Repeater {
                model: ["Position"].concat(positionNames)
                Rectangle {
                    width: 70
                    height: 30
                    Text {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        horizontalAlignment: Text.AlignHCenter
                        text: modelData
                        font.bold: true
                    }
                }
            }
        }

        // Create calendar
        Repeater {
            model: shiftTimes
            Loader {
                sourceComponent: calendarColumn
                onLoaded: {
                    item.colHeaderText = qsTr(modelData)
                    item.colNumber = index
                    calendarColumns.push(item)
                }
            }
        }

        onPositioningComplete: {
            // Load saved positions
            var tData = dataDictionary["column_data"]
            for (let i = 0; i < calendarColumns.length; i++) {
                for (let j = 0; j < workerNames.length; j++) {
                    calendarColumns[i].nameTiles[j].y = tData[i][calendarColumns[i].nameTiles[j].name]
                }
            }
        }
    } //Row

    // Error popup
    Dialog {
        id: dialogError
        anchors.centerIn: parent
        title: qsTr("Error")
        modal: true
        Text {
            text: qsTr("Worker cannot fulfill this position")
        }
        standardButtons: Dialog.Ok
    }

    // Blackout cell
    Component {
        id: blackout
        Rectangle {
            width: 70
            height: 30
            z: 20
            color: "black"
            x: calendar.x + calendar.width / 2
            y: bottomOfCalendar + cellHeight / 2
            Text {
                text: qsTr("[Unused]")
                color: "white"
                anchors.fill: parent
                verticalAlignment: Text.AlignVCenter
                horizontalAlignment: Text.AlignHCenter
            }

            Component.onCompleted: blackoutTiles.push(this)

            property bool inCalendar: y > topOfCalendar &&
                                      y < bottomOfCalendar &&
                                      x > lSideOfCalendar &&
                                      x < rSideOfCalendar

            // Draggable properties
            property bool dragActive: dragArea.drag.active
            onDragActiveChanged: {
                if (dragActive) Drag.start()
                else Drag.drop()
            }
            Drag.hotSpot.x: cellWidth / 2
            Drag.hotSpot.y: cellHeight / 2
            MouseArea {
                id: dragArea
                anchors.fill: parent
                drag.target: parent
                onReleased: {
                    if (!inCalendar) {
                        parent.x = calendar.x + calendar.width / 2
                        parent.y = calendar.height + calendar.y + 20
                    }
                    else duplicateBlackout()
                }
            }
        } //Rectangle
    } //Component


    // TODO: Delete blackout squares when moved off calendar
    function duplicateBlackout() {
        var sprite = blackout.createObject(app)
        if (sprite === null)
            console.log("Error creating object")
    }

    Loader {
        sourceComponent: blackout
    }
} //ApplicationWindow

