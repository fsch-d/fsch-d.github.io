function resizeScaledPlotly() {
  document.querySelectorAll(".scaled-plotly").forEach(wrapper => {
    const plot = wrapper.querySelector(".js-plotly-plot");
    if (!plot) return;

    const originalWidth = 650;
    const originalHeight = 650;

    const availableWidth = wrapper.clientWidth;
    const scale = Math.min(1, availableWidth / originalWidth);

    plot.style.transformOrigin = "top left";
    plot.style.transform = `scale(${scale})`;

    // Reserve the correct height after scaling
    wrapper.style.height = `${originalHeight * scale}px`;
  });
}

window.addEventListener("load", resizeScaledPlotly);
window.addEventListener("resize", resizeScaledPlotly);