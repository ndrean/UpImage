// import { S3Client, PutObjectCommand } from "@aws-sdk/client-s3";
// import { v4 as uuid } from "uuid";
const DROP_CLASSES = ["bg-blue-100", "border-blue-300"];

export default {
  async setHashName(file) {
    const ext = file.type.split("/").at(-1);
    const SHA1name = await this.calcSHA1(file);
    return new File([file], `${SHA1name}.${ext}`, {
      type: file.type,
    });
  },
  async calcSHA1(file) {
    const arrayBuffer = await file.arrayBuffer();
    const hash = await window.crypto.subtle.digest("SHA-1", arrayBuffer);
    const hashArray = Array.from(new Uint8Array(hash));
    const hashAsString = hashArray
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");
    return hashAsString;
  },
  async processFile(file, sizes) {
    return Promise.all(sizes.map((size) => this.fReader(file, size)));
  },
  fReader(file, MAX) {
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
  async handleFiles(files, sizes) {
    const renamedFiles = await Promise.all(
      [...files].map((file) => this.setHashName(file))
    );

    const fList = await Promise.all(
      renamedFiles.map((file) => this.processFile(file, sizes))
    );

    this.upload("images", fList.flat());
  },
  mounted() {
    const sizes = [200, 512, 1440];
    this.el.style.opacity = 0;

    this.el.addEventListener("change", async (evt) =>
      this.handleFiles(evt.target.files, sizes)
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
      return this.handleFiles(evt.dataTransfer.files, sizes);
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
