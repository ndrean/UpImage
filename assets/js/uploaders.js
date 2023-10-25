const Uploaders = {};

Uploaders.R2 = async function (entries, _onViewError) {
  try {
    const uploadPromises = await entries.map(({ file, meta }) => {
      let { url } = meta;

      return fetch(url, {
        method: "PUT",
        body: file,
        headers: {
          "Content-Type": "image/webp",
        },
      });
    });
    await Promise.all(uploadPromises);
  } catch (err) {
    throw new Error(err);
  }
};

Uploaders.S3 = () => {};

export default Uploaders;
