export default {
  mounted() {
    this.el.addEventListener("click", () => {
      navigator.clipboard.writeText(this.el.dataset.copyUrl);
      this.pushEvent("copy-clip", {});
    });
  },
};
