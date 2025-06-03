import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["textarea", "container", "tag", "input", "variable"]

  connect() {
    const parsedJson = JSON.parse(this.inputTarget.value)

    parsedJson.forEach(element => {
      const tag = this.addTag()

      switch (element.type) {
        case "operator":
          this.assignTagAsOperator(tag);
          tag.textContent = element.value
          break;
        case "unit":
          this.assignTagAsUnit(tag);
          tag.textContent = element.value
          break;
        case "property":
          this.assignTagAsVariable(tag);
          const variable = this.variableTargets.find(item => item.dataset.id === element.value)
          tag.textContent = variable.dataset.name
          tag.dataset.id = variable.dataset.id
          break;
      }
    })
  }

  onKeydown(event) {
    event.preventDefault();
    switch (event.key) {
      case "Backspace":
        this.handleBackspace();
        break;
      default:
        if (event.key.length === 1) { // Check if it's a printable character
          this.handleCharacterInput(event.key);
        }
        break;
    }
  }

  getLastTag() {
    return this.tagTargets[this.tagTargets.length - 1];
  }

  handleBackspace() {
    if (this.getLastTag().classList.contains("formula-builder-variable")) {
      this.getLastTag().remove();
    } else if (this.getLastTag(4).textContent.length > 1) {
      this.getLastTag().textContent = this.getLastTag().textContent.slice(0, -1);
    } else {
      this.getLastTag().remove();
    }
    return;
  }

  addTag() {
    const newTag = document.createElement("span");
    newTag.classList.add("tag", "is-light", "is-small");
    newTag.textContent = "";
    newTag.setAttribute("data-formula-builder-target", "tag");
    this.containerTarget.appendChild(newTag);
    return this.getLastTag();
  }

  handleCharacterInput(key) {
    if (key.match(/[0-9]/)) {
      if (!this.hasAnyTags() || !this.tagHasClass(this.getLastTag(), "formula-builder-unit")) { 
        this.assignTagAsUnit(this.addTag());
      }
      this.getLastTag().textContent += key;

    } else if (key.match(/[+\-*()/]/)) {
      this.addTag();
      this.assignTagAsOperator(this.getLastTag());
      this.getLastTag().textContent += key;
    }
  }

  tagHasClass(tag, className) {

    return tag.classList.contains(className);
  }

  assignTagAsUnit(tag) {
    tag.classList.add("has-text-link", "formula-builder-unit");
  }

  assignTagAsOperator(tag) {
    tag.classList.add("has-text-danger", "formula-builder-operator");
  }

  assignTagAsVariable(tag) {
    tag.classList.add("has-text-warning", "formula-builder-variable");
  }

  hasAnyTags() {
    return this.tagTargets.length > 0;
  }

  onVariableClick(event) {
    event.preventDefault();
    const variableId = event.currentTarget.getAttribute("data-id");
    const variableName = event.currentTarget.getAttribute("data-name");
    const tag = this.addTag();
    tag.textContent = variableName;
    this.assignTagAsVariable(tag);
    tag.setAttribute("data-id", variableId);
    this.textareaTarget.focus();
  }

  onSaveClick(event) {
    event.preventDefault();

    const formula = this.tagTargets.map(tag => {
      if (tag.classList.contains("formula-builder-unit")) {
        return { type: "unit", value: tag.textContent };
      } else if (tag.classList.contains("formula-builder-operator")) {
        return { type: "operator", value: tag.textContent };
      } else if (tag.classList.contains("formula-builder-variable")) {
        return { type: "property", value: tag.getAttribute("data-id") };
      }
    });
    const json = JSON.stringify(formula)
    this.inputTarget.value = json
  }

  focusTextarea() {
    this.textareaTarget.focus()
  }
}