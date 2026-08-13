#include <QApplication>

#include "main_window.h"

int main(int argc, char *argv[])
{
    QApplication app(argc, argv);
    QApplication::setApplicationName("Shatranj");
    QApplication::setOrganizationName("Shatranj");
    const QIcon appIcon = MainWindow::appIcon();
    QApplication::setWindowIcon(appIcon);

    MainWindow window;
    window.setWindowIcon(appIcon);
    window.showNormal();

    return app.exec();
}
