// import UAParser from "ua-parser-js";

export default {
  mounted() {
    // const UA = navigator.userAgent;
    // let parser = new UAParser(UA);
    this.handleEvent("screen", () => {
      this.pushEvent("page-size", {
        screenWidth: window.innerWidth,
        screenHeight: window.innerHeight,
      });
    });
  },
};
