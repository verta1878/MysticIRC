#ifndef APP_BANNER_H
#define APP_BANNER_H

#include <QWidget>
#include <QImage>
#include <functional>

class QKeyEvent;

class AppBanner : public QWidget {
    Q_DISABLE_COPY_MOVE(AppBanner)
public:
    explicit AppBanner(QWidget *parent = nullptr);

    std::function<void()> clicked;

protected:
    void keyPressEvent(QKeyEvent *event) override;
    void mousePressEvent(QMouseEvent *event) override;
    void mouseReleaseEvent(QMouseEvent *event) override;

private:
    void paintEvent(QPaintEvent *) override;
    void renderBridgeMosaic();

    struct MosaicPixel {
        int x, y, size, r, g, b, a;
    };

    QImage mosaicImage_;
    bool pressed_ = false;
};

#endif // APP_BANNER_H
