export const getAppVersion = async (req, res) => {
  try {
    return res.status(200).json({
      success: true,

      latestVersion: "2.0.0",
      latestBuild: 20,

      minimumVersion: "2.0.0",
      minimumBuild: 20,

      forceUpdate: true,

      releaseNotes:
        "HostelMess 2.0.0 includes major improvements, new features, performance updates, and bug fixes.",

      apkUrls: {
        "armeabi-v7a":
          "https://www.upload-apk.com/en/user/filemanager/PuhHiZjJ20qj2bH/download",
        "arm64-v8a":
          "https://www.upload-apk.com/en/user/filemanager/J4ZAT7VltwbW4bs/download",

        "x86_64":
          "https://www.upload-apk.com/en/user/filemanager/ujad91x4lsO2myT/download",
      },
    });
  } catch (error) {
    console.error("App Version Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to retrieve application version information.",
    });
  }
};