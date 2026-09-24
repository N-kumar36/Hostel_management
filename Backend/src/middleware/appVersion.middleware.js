const MINIMUM_BUILD = 20;
const MINIMUM_VERSION = "2.0.0";

/**
 * Blocks applications older than the minimum supported build.
 *
 * IMPORTANT:
 * /api/app-version must remain public and must NOT pass through
 * this middleware, otherwise old applications cannot discover
 * the update.
 */
export const requireSupportedAppVersion = (req, res, next) => {
  try {
    const appBuildHeader = req.headers["x-app-build"];
    const appVersionHeader = req.headers["x-app-version"];

    const appBuild = Number.parseInt(
      Array.isArray(appBuildHeader)
        ? appBuildHeader[0]
        : appBuildHeader || "0",
      10,
    );

    const appVersion =
      Array.isArray(appVersionHeader)
        ? appVersionHeader[0]
        : appVersionHeader || "unknown";

    // Missing/invalid build number means the client is not
    // using the new version-aware API protocol.
    if (!Number.isFinite(appBuild) || appBuild <= 0) {
      return res.status(426).json({
        success: false,
        code: "UPDATE_REQUIRED",
        message:
          "This version of HostelMess is no longer supported. Please update the application to continue.",
        currentVersion: appVersion,
        currentBuild: appBuild || null,
        minimumVersion: MINIMUM_VERSION,
        minimumBuild: MINIMUM_BUILD,
        forceUpdate: true,
      });
    }

    // Old application.
    if (appBuild < MINIMUM_BUILD) {
      return res.status(426).json({
        success: false,
        code: "UPDATE_REQUIRED",
        message:
          "This version of HostelMess is no longer supported. Please update the application to continue.",
        currentVersion: appVersion,
        currentBuild: appBuild,
        minimumVersion: MINIMUM_VERSION,
        minimumBuild: MINIMUM_BUILD,
        forceUpdate: true,
      });
    }

    // Supported application.
    return next();
  } catch (error) {
    console.error("App Version Middleware Error:", error);

    return res.status(500).json({
      success: false,
      message: "Unable to verify application version.",
    });
  }
};