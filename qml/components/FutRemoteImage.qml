import QtQuick
import Quickshell.Io
import "../services/FutImageCache.js" as ImageCache
import "../services/FutNetwork.js" as FutNetwork

// Only the bounded, dimension-checked PNG returned by the helper reaches Qt.
Item {
  id: image
  property string remoteSource: ""
  property bool newsPhoto: false
  readonly property string cacheKey: (newsPhoto ? "photo:" : "") + remoteSource
  property string fetchingKey: ""
  property string fetchingUrl: ""
  property int generation: 0
  property int fetchingGeneration: -1
  property bool hasSlot: false
  property alias source: decoded.source
  property alias sourceSize: decoded.sourceSize
  property alias fillMode: decoded.fillMode
  property alias asynchronous: decoded.asynchronous
  property alias cache: decoded.cache
  property alias mipmap: decoded.mipmap
  property alias smooth: decoded.smooth
  property alias horizontalAlignment: decoded.horizontalAlignment
  property alias verticalAlignment: decoded.verticalAlignment
  readonly property int status: decoded.status
  property bool showFallback: true
  readonly property bool fallbackVisible: showFallback && status !== Image.Ready
  implicitWidth: decoded.implicitWidth || 32
  implicitHeight: decoded.implicitHeight || 32
  Image {
    id: decoded
    anchors.fill: parent
    source: ""
    asynchronous: true
    sourceSize: Qt.size(128, 128)
  }
  Rectangle {
    anchors.fill: parent
    visible: image.fallbackVisible
    color: "#18808080"
    radius: Math.min(width, height) / 5
    Text {
      anchors.centerIn: parent
      text: image.newsPhoto ? "▧" : "◇"
      textFormat: Text.PlainText
      color: "#909090"
      font.pixelSize: Math.max(8, Math.min(parent.width, parent.height) * 0.45)
    }
  }
  onCacheKeyChanged: {
    generation++
    source = ""
    if (fetcher.running) fetcher.running = false
    restart.start()
  }
  Component.onCompleted: restart.start()
  Component.onDestruction: {
    if (hasSlot) ImageCache.release()
  }
  Timer {
    id: restart
    interval: 100
    onTriggered: {
      if (fetcher.running || image.hasSlot) { restart.start(); return }
      if (image.remoteSource === "") return
      var cached = ImageCache.lookup(image.cacheKey)
      if (cached !== undefined) { image.source = cached; return }
      if (!ImageCache.acquire()) { restart.start(); return }
      image.hasSlot = true
      image.fetchingUrl = image.remoteSource
      image.fetchingKey = image.cacheKey
      image.fetchingGeneration = image.generation
      fetcher.command = image.newsPhoto ? FutNetwork.photoCommand(image.fetchingUrl) : FutNetwork.imageCommand(image.fetchingUrl)
      fetcher.running = true
      deadline.start()
    }
  }
  Process {
    id: fetcher
    stdout: StdioCollector { id: output }
    onExited: function(code, status) {
      deadline.stop()
      var result = code === 0 ? output.text.trim() : ""
      if (result.indexOf("data:image/png;base64,") !== 0) result = ""
      if (image.fetchingGeneration === image.generation) {
        ImageCache.remember(image.fetchingKey, result)
        image.source = result
      }
      if (image.hasSlot) { ImageCache.release(); image.hasSlot = false }
    }
  }
  Timer {
    id: deadline
    interval: 10000
    onTriggered: {
      if (fetcher.running) fetcher.signal(9)
      else if (image.hasSlot) {
        // A missing interpreter can fail before the process emits exited.
        ImageCache.remember(image.fetchingKey, "")
        ImageCache.release()
        image.hasSlot = false
      }
    }
  }
}
