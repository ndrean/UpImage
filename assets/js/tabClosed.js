export default {
  mounted() {
    const uploader = document.querySelector("#upload-observer");
    if (!uploader) return;
    const links = document.querySelectorAll("a");
    const triggerBeforeUnload = () => this.pushEvent("tabclosed", {});
    for (let i = 0, len = links.length; i < len; i++) {
      links[i].addEventListener("click", triggerBeforeUnload);
    }
  },
};
