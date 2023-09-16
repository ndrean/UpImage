import UAParser from "ua-parser-js";

export default {
  mounted() {
    const UA = navigator.userAgent;
    let parser = new UAParser(UA);
    this.handleEvent("screen", () => {
      this.pushEvent("page-size", {
        screenWidth: window.innerWidth,
        screenHeight: window.innerHeight,
      });
      // alert(`Screen: w:${window.innerWidth}px, h:${window.innerHeight}px`);
    });

    // window.addEventListener("resize", () => {
    //   this.pushEvent("page-size", {
    //     screenWidth: window.innerWidth,
    //     screenHeight: window.innerHeight,
    //     // userAgent: UA,
    //     // device: parser.getDevice(),
    //     // trigger: "load",
    //   });

    //   alert(`resize: w:${window.innerWidth}px, h:${window.innerHeight}px`);
    // });
  },
};
