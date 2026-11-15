document.addEventListener("DOMContentLoaded", () => {

  function updateLightboxCaptions() {
    document.querySelectorAll(
      ".gslide.loaded"
    ).forEach(slide => {

      const img = slide.querySelector(".gslide-image img");
      const title = slide.querySelector(".gslide-title");

      if (!img || !title) return;

      const imageURL = new URL(img.src, document.baseURI).href;

      // Find the corresponding image on the original page
      const original = [...document.querySelectorAll(
        "figure.figure a.lightbox"
      )].find(link => link.href === imageURL);

      if (!original) return;

      const caption = original.closest("figure")
        ?.querySelector("figcaption");

      if (!caption) return;

      // Copy the already-rendered caption
      if (title.dataset.captionCopied === "true") return;

      title.innerHTML = caption.innerHTML;
      title.dataset.captionCopied = "true";
    });
  }

  const observer = new MutationObserver(updateLightboxCaptions);

  observer.observe(document.body, {
    childList: true,
    subtree: true
  });

});