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
          "https://YOUR-APK-HOST/hostelmess-2.0.0-armeabi-v7a.apk",

        "arm64-v8a":
          "https://YOUR-APK-HOST/hostelmess-2.0.0-arm64-v8a.apk",

        "x86_64":
          "https://YOUR-APK-HOST/hostelmess-2.0.0-x86_64.apk",
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