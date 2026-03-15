import multer from "multer";
import { storage } from "../config/fireBase.config.js"; // Added .js
import { ref, uploadBytesResumable, getDownloadURL } from "firebase/storage";

export const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 5 * 1024 * 1024 },
});


export const ProfileToFirebase = (file) => {
  return new Promise((resolve, reject) => {
    if (!file) return reject("No file provided");

    const storageRef = ref(storage, `profilePic/${Date.now()}_${file.originalname}`);
    const uploadTask = uploadBytesResumable(storageRef, file.buffer, {
      contentType: file.mimetype,
    });

    uploadTask.on(
      "state_changed",
      null,
      (error) => reject(error),
      async () => {
        try {
          const downloadURL = await getDownloadURL(uploadTask.snapshot.ref);
          resolve(downloadURL);
        } catch (err) {
          reject(err);
        }
      }
    );
  });
};

// comolains upload file
export const uploadToFirebase = (file) => {
  return new Promise((resolve, reject) => {
    if (!file) return reject("No file provided");

    const storageRef = ref(storage, `complains/${Date.now()}_${file.originalname}`);
    const uploadTask = uploadBytesResumable(storageRef, file.buffer, {
      contentType: file.mimetype,
    });

    uploadTask.on(
      "state_changed",
      null,
      (error) => reject(error),
      async () => {
        try {
          const downloadURL = await getDownloadURL(uploadTask.snapshot.ref);
          resolve(downloadURL);
        } catch (err) {
          reject(err);
        }
      }
    );
  });
};

// fine img upload 
export const fineUploadFirebase = (file) => {
  return new Promise((resolve, reject) => {
    if (!file) return reject("No file provided");

    const storageFef = ref(storage, `fines/${Date.now()}_${file.originalname}`);

    const uploadTask = uploadBytesResumable(storageFef, file.buffer, {
      contentType: file.mimetype,
    })
    uploadTask.on(
      "state_changed",
      null,
      (error) => reject(error),
      async () => {
        try {
          const downloadURL = await getDownloadURL(uploadTask.snapshot.ref);
          resolve(downloadURL);

        } catch (error) {
          reject(error);

        }
      }
    )


  })
}