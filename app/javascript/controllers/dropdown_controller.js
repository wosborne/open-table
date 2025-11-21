import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["dropdown", "menu", "template"]
  static values = { 
    portal: Boolean
  }

  connect() {
    this.boundHandleClick = this.handleClick.bind(this)
    this.boundHandleKeydown = this.handleKeydown.bind(this)
    
    document.addEventListener("click", this.boundHandleClick)
    document.addEventListener("keydown", this.boundHandleKeydown)
  }

  disconnect() {
    document.removeEventListener("click", this.boundHandleClick)
    document.removeEventListener("keydown", this.boundHandleKeydown)
    this.cleanup()
  }

  handleClick(event) {
    if (!this.element.contains(event.target) && 
        (!this.portalMenu || !this.portalMenu.contains(event.target))) {
      this.close()
    }
  }

  handleKeydown(event) {
    if (event.key === "Escape") {
      this.close()
    }
  }

  open() {
    if (this.portalValue) {
      this.createPortal()
    } else {
      this.dropdownTarget.classList.add("is-active")
    }
  }

  close() {
    if (this.portalValue) {
      this.cleanup()
    } else {
      this.dropdownTarget.classList.remove("is-active")
    }
  }

  toggle() {
    if (this.portalValue) {
      // For portal dropdowns, check if portal menu exists
      if (this.portalMenu) {
        this.close()
      } else {
        this.open()
      }
    } else {
      this.dropdownTarget.classList.toggle("is-active")
    }
  }

  createPortal() {
    const portalContainer = document.getElementById('portal-container')
    if (!portalContainer) return
    
    if (!this.hasTemplateTarget) {
      console.error('Portal dropdowns require a template target')
      return
    }
    
    const rect = this.dropdownTarget.getBoundingClientRect()
    
    const templateContent = this.templateTarget.content.cloneNode(true)
    portalContainer.appendChild(templateContent)
    this.portalMenu = portalContainer.lastElementChild
    
    this.portalMenu.classList.add('dropdown-portal')
    this.portalMenu.style.top = `${rect.bottom}px`
    this.portalMenu.style.left = `${rect.left}px`
  }

  cleanup() {
    if (this.portalMenu) {
      this.portalMenu.remove()
      this.portalMenu = null
    }
  }
}
