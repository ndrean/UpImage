const DROP_CLASSES = ["bg-blue-100", "border-blue-300"];
const SIZES = [200, 512, 1440];

export default {
  /**
   * Renames a File object with its SHA1 hash and keep the extension
   * source: https://developer.mozilla.org/en-US/docs/Web/API/SubtleCrypto/digest#converting_a_digest_to_a_hex_string
   * @param {File} file - the file input
   * @returns {Promise<File>} a promise that resolves with a renamed File object
   */
  async setHashName(file) {
    const ext = file.type.split("/").at(-1);
    const SHA1name = await this.calcSHA1(file);
    return new File([file], `${SHA1name}.${ext}`, {
      type: file.type,
    });
  },
  /**
   * Calculates a SHA1 hash using the native Web Crypto API.
   * @param {File} file - the file to calculate the hash on.
   * @returns {Promise<String>} a promise that resolves to hash as String
   */
  async calcSHA1(file) {
    const arrayBuffer = await file.arrayBuffer();
    const hash = await window.crypto.subtle.digest("SHA-1", arrayBuffer);
    const hashArray = Array.from(new Uint8Array(hash));
    const hashAsString = hashArray
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
    return hashAsString;
  },
  /**
   *
   * @param {File} file  - the file
   * @param {number[]} SIZES - un array of sizes to resize to image to
   * @returns {Promise<File[]>} a promise that resolves to an array of resized images
   */
  async processFile(file, SIZES) {
    return Promise.all(SIZES.map((size) => this.fReader(file, size)));
  },
  /**
   * Reads an image file, resizes it to a given max size, and converts into WEBP format et returns it
   * @param {File} file  - the file image
   * @param {number} MAX  - the max size of the image in px
   * @returns {Promise<File>} resolves with the converted file
   */
  async fReader(file, MAX) {
    const self = this;

    return new Promise((resolve, reject) => {
      if (file) {
        const img = new Image();
        const newUrl = URL.createObjectURL(file);
        img.src = newUrl;

        img.onload = function () {
          URL.revokeObjectURL(newUrl);
          const { w, h } = self.resizeMax(img.width, img.height, MAX);
          const canvas = document.createElement("canvas");
          if (canvas.getContext) {
            const ctx = canvas.getContext("2d");
            canvas.width = w;
            canvas.height = h;
            ctx.drawImage(img, 0, 0, w, h);
            // convert the image from the canvas into a Blob and convert into WEBP format
            canvas.toBlob(
              (blob) => {
                const name = file.name.split(".")[0];
                const convertedFile = new File([blob], `${name}-m${MAX}.webp`, {
                  type: "image/webp",
                });
                resolve(convertedFile);
              },
              "image/webp",
              0.75
            );
          }
        };
        img.onerror = function () {
          reject("Error loading image");
        };
      } else {
        reject("No file selected");
      }
    });
  },
  resizeMax(w, h, MAX) {
    if (w > h) {
      if (w > MAX) {
        h = h * (MAX / w);
        w = MAX;
      }
    } else {
      if (h > MAX) {
        w = w * (MAX / h);
        h = MAX;
      }
    }
    return { w, h };
  },
  /**
   * Takes a FileList and an array of sizes, then rename then with the SHA1 hash, then resizes the images according to a list of given sizes, converts them to WEBP format, and uploads them.
   * @param {FileList} files
   * @param {number[]} SIZES
   */
  async handleFiles(files, SIZES) {
    const renamedFiles = await Promise.all(
      [...files].map((file) => this.setHashName(file))
    );

    const fList = await Promise.all(
      renamedFiles.map((file) => this.processFile(file, SIZES))
    );

    this.upload("images", fList.flat());
  },
  /*
  inspired by: https://github.com/elixir-nx/bumblebee/blob/main/examples/phoenix/image_classification.exs
  */
  mounted() {
    this.el.style.opacity = 0;

    this.el.addEventListener("change", async (evt) =>
      this.handleFiles(evt.target.files, SIZES)
    );

    // Drag and drop
    this.el.addEventListener("dragover", (evt) => {
      evt.stopPropagation();
      evt.preventDefault();
      evt.dataTransfer.dropEffect = "copy";
    });

    this.el.addEventListener("drop", async (evt) => {
      evt.stopPropagation();
      evt.preventDefault();
      return this.handleFiles(evt.dataTransfer.files, SIZES);
    });

    this.el.addEventListener("dragenter", () =>
      this.el.classList.add(...DROP_CLASSES)
    );

    this.el.addEventListener("dragleave", (evt) => {
      if (!this.el.contains(evt.relatedTarget)) {
        this.el.classList.remove(...DROP_CLASSES);
      }
    });

    this.el.addEventListener("drop", () =>
      this.el.classList.remove(...DROP_CLASSES)
    );
  },
};
