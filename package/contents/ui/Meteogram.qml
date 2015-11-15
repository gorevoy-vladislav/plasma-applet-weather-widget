/*
 * Copyright 2015  Martin Kotelnik <clearmartin@seznam.cz>
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License as
 * published by the Free Software Foundation; either version 2 of
 * the License, or (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http: //www.gnu.org/licenses/>.
 */
import QtQuick 2.2
import QtQuick.Layouts 1.1
import QtGraphicalEffects 1.0
import org.kde.plasma.components 2.0 as PlasmaComponents
import "../code/temperature-utils.js" as TemperatureUtils

Item {
    id: meteogram
    
    property bool enableRendering: renderMeteogram || currentProvider.id !== 'yrno'
    
    property int temperatureSizeY: 21
    property int pressureSizeY: 101
    property int pressureMultiplier: Math.round((pressureSizeY - 1) / (temperatureSizeY - 1))
    
    property int graphLeftMargin: 28
    property int graphTopMargin: 20
    property double graphWidth: meteogram.width - graphLeftMargin * 2
    property double graphHeight: meteogram.height - graphTopMargin * 2
    
    property int hourModelSize: 0
    
    
    property var dataArray: []
    
    property int dataArraySize: 2
    property double sampleWidth: graphWidth / (dataArraySize - 1)

    property double temperatureAdditiveY: 0
    property double temperatureMultiplierY: graphHeight / (temperatureSizeY - 1)
    
    property int pressureAdditiveY: - 950
    property double pressureMultiplierY: graphHeight / (pressureSizeY - 1)
    
    property bool meteogramModelChanged: main.meteogramModelChanged
    
    property int precipitationFontPixelSize: 7
    property int precipitationHeightMultiplier: 15
    property int precipitationLabelMargin: 10
    
    property color pressureColor: Qt.rgba(0.3, 1.0, 0.3, 1.0)
    
    property bool textColorLight: ((theme.textColor.r + theme.textColor.g + theme.textColor.b) / 3) > 0.5
    property color gridColor: textColorLight ? Qt.tint(theme.textColor, '#80000000') : Qt.tint(theme.textColor, '#80FFFFFF')
    property color gridColorHighlight: textColorLight ? Qt.tint(theme.textColor, '#50000000') : Qt.tint(theme.textColor, '#50FFFFFF')
    
    onTemperatureMultiplierYChanged: {
        dbgprint('temperatureMultiplierY changed to: ' + temperatureMultiplierY)
        modelUpdated()
    }
    
    onMeteogramModelChangedChanged: {
        dbgprint('meteogram changed')
        modelUpdated()
    }
    
    function _appendHorizontalModel(meteogramModelObj) {
        var oneHourMs = 3600000
        var dateFrom = Date.fromLocaleString(locale, meteogramModelObj.from, datetimeFormat)
        var dateTo = Date.fromLocaleString(locale, meteogramModelObj.to, datetimeFormat)
        var differenceHours = Math.round((dateTo.getTime() - dateFrom.getTime()) / oneHourMs)
        dbgprint('differenceHours=' + differenceHours + ', oneHourMs=' + oneHourMs + ', dateFrom=' + dateFrom + ', dateTo=' + dateTo)
        if (differenceHours > 20) {
            return
        }
        for (var i = 0; i < differenceHours; i++) {
            hourGridModel.append({
                dateFrom: new Date(dateFrom.getTime() + i * oneHourMs),
                precipitationAvg: meteogramModelObj.precipitationAvg,
                precipitationMin: meteogramModelObj.precipitationMin,
                precipitationMax: meteogramModelObj.precipitationMax,
                canShowDay: true,
                canShowPrec: true
            })
        }
    }
    
    function _adjustLastDay() {
        for (var i = hourGridModel.count - 5; i < hourGridModel.count; i++) {
            hourGridModel.setProperty(i, 'canShowDay', false)
        }
        hourGridModel.setProperty(hourGridModel.count - 1, 'canShowPrec', false)
    }
    
    function modelUpdated() {
        
        dbgprint('meteogram model updated ' + meteogramModel.count)
        dataArraySize = meteogramModel.count
        
        if (dataArraySize === 0) {
            dbgprint('model is empty')
            return
        }
        
        hourGridModel.clear()
        
        var minValue = null
        var maxValue = null
        
        for (var i = 0; i < dataArraySize; i++) {
            var obj = meteogramModel.get(i)
            _appendHorizontalModel(obj)
            var value = obj.temperature
            if (minValue === null) {
                minValue = value
                maxValue = value
                continue
            }
            if (value < minValue) {
                minValue = value
            }
            if (value > maxValue) {
                maxValue = value
            }
        }
        
        _adjustLastDay()
        
        dbgprint('minValue: ' + minValue)
        dbgprint('maxValue: ' + maxValue)
        dbgprint('temperatureSizeY: ' + temperatureSizeY)
        
        var mid = (maxValue - minValue) / 2 + minValue
        var halfSize = temperatureSizeY / 2
        
        temperatureAdditiveY = Math.round(- (mid - halfSize))
        
        dbgprint('temperatureAdditiveY: ' + temperatureAdditiveY)
        
        redrawCanvas()
    }
    
    function redrawCanvas() {
        
        print('redrawing canvas with temperatureMultiplierY=' + temperatureMultiplierY)
        
        var newPathElements = []
        var newPressureElements = []
        
        if (dataArraySize === 0 || temperatureMultiplierY > 1000000 || temperatureMultiplierY === 0) {
            return
        }
        
        for (var i = 0; i < dataArraySize; i++) {
            var dataObj = meteogramModel.get(i)
            
            dbgprint('hour: ' + dataObj.from)
            
            var rawTempY = temperatureSizeY - (dataObj.temperature + temperatureAdditiveY)
            dbgprint('realTemp: ' + dataObj.temperature + ', rawTempY: ' + rawTempY)
            var temperatureY = rawTempY * temperatureMultiplierY
            
            var rawPressY = pressureSizeY - (dataObj.pressureHpa + pressureAdditiveY)
            dbgprint('realPress: ' + dataObj.pressureHpa + ', rawTempY: ' + rawPressY)
            var pressureY = rawPressY * pressureMultiplierY
            
            if (i === 0) {
                temperaturePath.startY = temperatureY
                pressurePath.startY = pressureY
                continue
            }
            
            newPathElements.push(Qt.createQmlObject('import QtQuick 2.0; PathCurve { x: ' + (i * sampleWidth) + '; y: ' + temperatureY + ' }', meteogram, "dynamicTemperature" + i))

            newPressureElements.push(Qt.createQmlObject('import QtQuick 2.0; PathCurve { x: ' + (i * sampleWidth) + '; y: ' + pressureY + ' }', meteogram, "dynamicPressure" + i))
        }
        
        temperaturePath.pathElements = newPathElements
        pressurePath.pathElements = newPressureElements
        
        meteogramCanvas.requestPaint()
        
    }
    
    ListModel {
        id: verticalGridModel
    }
    
    ListModel {
        id: hourGridModel
    }
    
    Component.onCompleted: {
        for (var i = 0; i < temperatureSizeY; i++) {
            verticalGridModel.append({
                num: i
            })
        }
    }
    
    Item {
        id: graph
        width: graphWidth
        height: graphHeight
        anchors.centerIn: parent
        anchors.topMargin: -(graphHeight / temperatureSizeY) * 0.5
        
        visible: enableRendering
        
        ListView {
            id: horizontalLines
            model: verticalGridModel
            anchors.fill: parent
            
            interactive: false
            
            delegate: Item {
                height: horizontalLines.height / (temperatureSizeY - 1)
                width: horizontalLines.width
                
                visible: num % 2 === 0
                
                Rectangle {
                    width: parent.width
                    height: 1
                    color: gridColor
                    anchors.verticalCenter: parent.verticalCenter
                }
                
                PlasmaComponents.Label {
                    text: TemperatureUtils.getTemperatureNumber(-temperatureAdditiveY + (temperatureSizeY - num), fahrenheitEnabled) + '°'
                    height: parent.height
                    width: graphLeftMargin - 2
                    horizontalAlignment: Text.AlignRight
                    anchors.left: parent.left
                    anchors.leftMargin: -graphLeftMargin
                    font.pixelSize: 10
                }
                
                PlasmaComponents.Label {
                    text: (-pressureAdditiveY + (pressureSizeY - 1 - num * pressureMultiplier))
                    height: parent.height
                    width: graphLeftMargin - 2
                    horizontalAlignment: Text.AlignLeft
                    anchors.right: parent.right
                    anchors.rightMargin: -graphLeftMargin
                    font.pixelSize: 10
                    color: pressureColor
                }
            }
        }
        
        ListView {
            id: hourGrid
            model: hourGridModel
            
            property double hourItemWidth: hourGridModel.count === 0 ? 0 : parent.width / (hourGridModel.count - 1)
            
            width: hourItemWidth * hourGridModel.count
            height: parent.height
            
            anchors.fill: parent
            anchors.topMargin: -graph.anchors.topMargin
            anchors.bottomMargin: graph.anchors.topMargin
            anchors.leftMargin: -(hourItemWidth/2)
            orientation: ListView.Horizontal
            
            interactive: false
            
            delegate: Item {
                height: hourGrid.height
                width: hourGrid.hourItemWidth
                
                property int hourFrom: dateFrom.getHours()
                property bool dayBegins: hourFrom === 0
                property bool hourVisible: hourFrom % 2 === 0
                
                property double precAvg: parseFloat(precipitationAvg) || 0
                property double precMax: parseFloat(precipitationMax) || 0
                
                property bool precLabelVisible: precAvg > 0 || precMax > 0
                
                PlasmaComponents.Label {
                    id: dayTest
                    text: Qt.locale().dayName(dateFrom.getDay(), Locale.LongFormat)
                    height: graphTopMargin - 2
                    anchors.top: parent.top
                    anchors.topMargin: -graphTopMargin
                    anchors.left: parent.left
                    anchors.leftMargin: parent.width / 2
                    font.pixelSize: theme.defaultFont.pixelSize
                    visible: dayBegins && canShowDay
                }
                
                Rectangle {
                    width: dayBegins ? 2 : 1
                    height: parent.height
                    color: dayBegins ? gridColorHighlight : gridColor
                    anchors.horizontalCenter: parent.horizontalCenter
                    visible: hourVisible
                }
                
                PlasmaComponents.Label {
                    id: hourText
                    text: (hourFrom < 10 ? '0' + hourFrom : hourFrom)
                    verticalAlignment: Text.AlignTop
                    horizontalAlignment: Text.AlignHCenter
                    height: graphTopMargin - 2
                    anchors.bottom: parent.bottom
                    anchors.bottomMargin: -graphTopMargin
                    anchors.horizontalCenter: parent.horizontalCenter
                    font.pixelSize: 10
                    visible: hourVisible
                }
                
                PlasmaComponents.Label {
                    text: '00'
                    verticalAlignment: Text.AlignTop
                    horizontalAlignment: Text.AlignLeft
                    anchors.top: hourText.top
                    anchors.left: hourText.right
                    font.pixelSize: 7
                    visible: hourVisible
                }
                
                Item {
                    visible: canShowPrec
                    anchors.fill: parent
                    
                    Rectangle {
                        id: precipitationMaxRect
                        width: parent.width
                        height: (precMax < precAvg ? precAvg : precMax) * precipitationHeightMultiplier
                        color: theme.highlightColor
                        anchors.left: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: precipitationLabelMargin
                        opacity: 0.5
                    }
                    
                    Rectangle {
                        id: precipitationAvgRect
                        width: parent.width
                        height: precAvg * precipitationHeightMultiplier
                        color: theme.highlightColor
                        anchors.left: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: precipitationLabelMargin
                    }
                    
                    PlasmaComponents.Label {
                        text: precipitationMin
                        verticalAlignment: Text.AlignTop
                        horizontalAlignment: Text.AlignHCenter
                        anchors.top: parent.bottom
                        anchors.topMargin: -precipitationLabelMargin
                        anchors.horizontalCenter: precipitationAvgRect.horizontalCenter
                        font.pixelSize: precipitationFontPixelSize
                        visible: precLabelVisible
                    }

                    PlasmaComponents.Label {
                        text: precipitationMax || precipitationAvg
                        verticalAlignment: Text.AlignBottom
                        horizontalAlignment: Text.AlignHCenter
                        anchors.bottom: precipitationMaxRect.top
                        anchors.horizontalCenter: precipitationAvgRect.horizontalCenter
                        font.pixelSize: precipitationFontPixelSize
                        visible: precLabelVisible
                    }
                }
                
                Component.onCompleted: {
                    dbgprint('avg=' + precipitationAvg + ', max=' + precipitationMax + ', min=' + precipitationMin)
                }
                
            }
        }
        
        Canvas {
            id: meteogramCanvas
            anchors.fill: parent
            anchors.topMargin: (horizontalLines.height / temperatureSizeY) * 0.5
            anchors.bottomMargin: (horizontalLines.height / temperatureSizeY) * 0.5
            contextType: '2d'

            Path {
                id: pressurePath
                startX: 0
            }
            
            Path {
                id: temperaturePath
                startX: 0
            }
            
            onPaint: {
                context.clearRect(0, 0, meteogramCanvas.width, meteogramCanvas.height)
                
                context.strokeStyle = pressureColor
                context.lineWidth = 1;
                context.path = pressurePath
                context.stroke()
                
                context.strokeStyle = Qt.rgba(1.0, 0.1, 0.1, 1.0)
                context.lineWidth = 2;
                context.path = temperaturePath
                context.stroke()
            }
        }
    }
    
    Item {
        
        visible: !enableRendering
        
        PlasmaComponents.Label {
            id: noImageText
            anchors.fill: parent
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
            anchors.top: parent.top
            anchors.topMargin: headingHeight
            text: loadingError ? 'Offline mode' : 'Loading image...'
        }
        
        Image {
            id: overviewImage
            cache: false
            source: !enableRendering ? undefined : overviewImageSource
            anchors.fill: parent
        }
        
        states: [
            State {
                name: 'error'
                when: !enableRendering && (overviewImage.status == Image.Error || overviewImage.status == Image.Null)

                StateChangeScript {
                    script: {
                        dbgprint('image loading error')
                        imageLoadingError = true
                    }
                }
            },
            State {
                name: 'loading'
                when: !enableRendering && (overviewImage.status == Image.Loading || overviewImage.status == Image.Ready)

                StateChangeScript {
                    script: {
                        imageLoadingError = false
                    }
                }
            }
        ]
        
    }
    
}
