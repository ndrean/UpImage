export default {
  mounted() {
    const uploader = document.querySelector("#upload-observer");
    if (!uploader) return;
    document
      .querySelectorAll("a")
      .forEach(
        (link) => (link.onclick = () => this.pushEvent("tabclosed", {}))
      );
  },
};
