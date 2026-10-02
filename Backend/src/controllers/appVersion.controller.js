export const getAppVersion = async (req, res) => {
  try {
    return res.status(200).json({
      success: true,

      latestVersion: "2.0.1",
      latestBuild: 21,

      minimumVersion: "2.0.1",
      minimumBuild: 21,

      forceUpdate: true,

      releaseNotes:
        "HostelMess 2.0.1 includes major improvements, new features, performance updates, and bug fixes.",

      apkUrls: {
        "armeabi-v7a":
          "https://github.com/N-kumar36/Hostel_management/releases/download/v2.0.1/app-armeabi-v7a-release.apk",
        "arm64-v8a":
          "https://github.com/N-kumar36/Hostel_management/releases/download/v2.0.1/app-arm64-v8a-release.apk",

        "x86_64":
          "https://github.com/N-kumar36/Hostel_management/releases/download/v2.0.1/app-x86_64-release.apk",
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