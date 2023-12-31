// detect if user is active, otherwise trigger temp file cleanup
export default {
  mounted() {
    const pushActivity = (() => {
      let active = true;
      //   delay 10 min
      const delay = 10 * 60 * 1000;

      return () => {
        if (active) {
          active = false;

          setTimeout(() => {
            active = true;

            this.pushEventTo("#" + this.el.id, "inactivity");
          }, delay);
        }
      };
    })();

    pushActivity();
    window.addEventListener("mousemove", pushActivity);
    window.addEventListener("scroll", pushActivity);
    window.addEventListener("keydown", pushActivity);
    window.addEventListener("resize", pushActivity);
  },
};
