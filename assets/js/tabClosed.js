// read click on the 2 links to pushEvent to server to clean the temp files
export default {
  mounted() {
    const uploader = document.querySelector("#upload-observer");
    if (!uploader) return;
    document.querySelectorAll("a").forEach((link) =>
      link.addEventListener("click", () => {
        return this.pushEvent("tabclosed", {});
      })
    );
  },
};
