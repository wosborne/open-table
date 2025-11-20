import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["categorySelect", "optionsFrame", "skeleton"]
  static values = { 
    accountSlug: String 
  }

  categoryChanged(event) {
    const categoryId = event.target.value;
    const accountSlug = this.accountSlugValue;
    
    if (categoryId) {
      // Show skeleton loader
      this.showSkeleton();
      this.optionsFrameTarget.src = `/${accountSlug}/products/ebay_category_aspects?category_id=${categoryId}`;
    } else {
      this.hideSkeleton();
      this.optionsFrameTarget.src = `/${accountSlug}/products/ebay_category_aspects?clear=true`;
    }
  }

  showSkeleton() {
    if (this.hasSkeletonTarget) {
      this.skeletonTarget.classList.remove("is-hidden");
    }
  }

  hideSkeleton() {
    if (this.hasSkeletonTarget) {
      this.skeletonTarget.classList.add("is-hidden");
    }
  }

  // Hide skeleton when content loads
  frameLoaded() {
    this.hideSkeleton();
  }
}