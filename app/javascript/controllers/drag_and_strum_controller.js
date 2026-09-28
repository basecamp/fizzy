import { Controller } from "@hotwired/stimulus"

const INSTRUMENTS = [
  [
   "/audio/vibes/B3.mp3",
   "/audio/vibes/C3.mp3",
   "/audio/vibes/D4.mp3",
   "/audio/vibes/E3.mp3",
   "/audio/vibes/Fsharp4.mp3",
   "/audio/vibes/G3.mp3"
  ],
  [
    "/audio/banjo/B3.mp3",
    "/audio/banjo/C3.mp3",
    "/audio/banjo/D4.mp3",
    "/audio/banjo/E3.mp3",
    "/audio/banjo/Fsharp4.mp3",
    "/audio/banjo/G3.mp3"
  ],
  [
    "/audio/harpsichord/B3.mp3",
    "/audio/harpsichord/C3.mp3",
    "/audio/harpsichord/D4.mp3",
    "/audio/harpsichord/E3.mp3",
    "/audio/harpsichord/Fsharp4.mp3",
    "/audio/harpsichord/G3.mp3"
  ],
  [
    "/audio/mandolin/B3.mp3",
    "/audio/mandolin/C3.mp3",
    "/audio/mandolin/D4.mp3",
    "/audio/mandolin/E3.mp3",
    "/audio/mandolin/Fsharp4.mp3",
    "/audio/mandolin/G3.mp3"
  ],
  [
   "/audio/piano/B3.mp3",
   "/audio/piano/C3.mp3",
   "/audio/piano/D4.mp3",
   "/audio/piano/E3.mp3",
   "/audio/piano/Fsharp4.mp3",
   "/audio/piano/G3.mp3"
  ],
]

export default class extends Controller {
  static targets = [ "container" ]

  connect() {
    this.instrumentIndex = 0
    this.preloadedAudioFiles = []
    this.boundHandleKeyDown = this.handleKeyDown.bind(this)
    document.addEventListener("keydown", this.boundHandleKeyDown);
  }

  disconnect() {
    document.removeEventListener("keydown", this.boundHandleKeyDown);
  }

  handleKeyDown(event) {
    if (event.shiftKey) {
      this.instrumentIndex = this.#getInstrumentIndex(event)

      if (this.instrumentIndex < INSTRUMENTS.length) {
        this.#preloadAudioFiles(this.instrumentIndex)
      }
    }
  }

  dragEnter(event) {
    event.preventDefault()
    const container = this.#containerContaining(event.target)

    if (!container) { return }

    if (container !== this.sourceContainer && event.shiftKey) {
      this.#playSound()
    }
  }

  #getInstrumentIndex(event) {
    const number = Number(event.code.replace("Digit", ""))
    return isNaN(number) ? 0 : number
  }

  #preloadAudioFiles(instrumentIndex) {
    this.preloadedAudioFiles = []
    const audioFiles = INSTRUMENTS[instrumentIndex];

    if (audioFiles) {
      this.preloadedAudioFiles = audioFiles.map(file => {
        const audio = new Audio(file)
        audio.load()
        return audio
      })
    }
  }

  #containerContaining(element) {
    return this.containerTargets.find(container => container.contains(element) || container === element)
  }

  #playSound() {
    const randomIndex = Math.floor(Math.random() * this.preloadedAudioFiles.length)
    const audio = this.preloadedAudioFiles[randomIndex]
    const audioInstance = new Audio(audio.src)

    audioInstance.play()
  }
}
