import { Controller } from "@hotwired/stimulus"
import { initPixiApp } from "pixi_app"

export default class extends Controller {
  static values = {
    buildingPlacements: Array,
    tilesheetUrl: String
  }

  async connect() {
    this.app = await initPixiApp(this.element.id, {
      buildingPlacements: this.buildingPlacementsValue,
      tilesheetUrl: this.tilesheetUrlValue
    })
  }

  disconnect() {
    this.app?.cleanup?.()
    this.app?.destroy(true)
    this.app = null
  }
}
