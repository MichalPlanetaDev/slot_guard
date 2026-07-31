import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "button"]

  toggle() {
    const revealPassword = this.inputTargets.every(
      (input) => input.type === "password"
    )

    this.inputTargets.forEach((input) => {
      input.type = revealPassword ? "text" : "password"
    })

    this.buttonTarget.textContent = revealPassword ? "Hide" : "Show"
    this.buttonTarget.setAttribute(
      "aria-pressed",
      revealPassword.toString()
    )
  }
}
