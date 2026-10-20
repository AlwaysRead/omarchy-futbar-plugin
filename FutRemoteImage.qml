import QtQuick
import Quickshell.Io
import "FutImageCache.js" as ImageCache
import "FutNetwork.js" as FutNetwork

// Only the bounded, dimension-checked PNG returned by the helper reaches Qt.
Image {
  id: image
  property string remoteSource: ""
  property string fetchingUrl: ""
  property int generation: 0
  property int fetchingGeneration: -1
  property bool hasSlot: false
  source: ""
  asynchronous: true
  sourceSize: Qt.size(128, 128)
  onRemoteSourceChanged: {
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
      var cached = ImageCache.lookup(image.remoteSource)
      if (cached !== undefined) { image.source = cached; return }
      if (!ImageCache.acquire()) { restart.start(); return }
      image.hasSlot = true
      image.fetchingUrl = image.remoteSource
      image.fetchingGeneration = image.generation
      fetcher.command = FutNetwork.imageCommand(image.fetchingUrl)
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
        ImageCache.remember(image.fetchingUrl, result)
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
        ImageCache.remember(image.fetchingUrl, "")
        ImageCache.release()
        image.hasSlot = false
      }
    }
  }
}
