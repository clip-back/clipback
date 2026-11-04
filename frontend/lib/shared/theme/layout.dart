const double phoneWidth = 375;

const double phoneHeight = 812;

const double appHeaderHeight = 64;

/// Phones fill the available width; larger windows retain the design canvas.
/// Keep [phoneWidth] unchanged for fixed cards and dialogs.
double appContentWidth(double availableWidth) =>
    availableWidth < 600 ? availableWidth : phoneWidth;
