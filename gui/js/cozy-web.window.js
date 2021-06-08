const { BrowserWindow } = require('electron')

const log = require('../../core/app').logger({
  component: 'GUI'
})

const SCREEN_WIDTH = 1060
const SCREEN_HEIGHT = 800

const WindowManager = require('./window_manager')

module.exports = class CozyWebWM extends WindowManager {
  windowOptions() {
    return {
      title: 'Cozy',
      show: true,
      center: true,
      width: SCREEN_WIDTH,
      height: SCREEN_HEIGHT
    }
  }

  ipcEvents() {
    return {}
  }

  hash() {
    return '#cozy'
  }

  on(event /*: Event */, handler /*: Function */) {
    this.win.on(event, handler)
  }

  create() {
    this.log.debug('create')
    const opts = {
      ...this.windowOptions(),
      autoHideMenuBar: true,
      webPreferences: {
        nodeIntegration: false,
        contextIsolation: true,
        enableRemoteModule: false
      }
    }
    // https://github.com/AppImage/AppImageKit/wiki/Bundling-Electron-apps
    //if (process.platform === 'linux') {
    //  opts.icon = path.join(__dirname, '../images/icon.png')
    //}
    this.win = new BrowserWindow(opts)
    this.win.on('unresponsive', () => {
      this.log.warn('Web page becomes unresponsive')
    })
    this.win.on('responsive', () => {
      this.log.warn('Web page becomes responsive again')
    })
    this.win.webContents.on(
      'did-fail-load',
      (event, errorCode, errorDescription, url, isMainFrame) => {
        const err = new Error(errorDescription)
        err.code = errorCode
        this.log.error(
          { err, url, isMainFrame, sentry: true },
          'failed loading window content'
        )
      }
    )
    this.centerOnScreen(opts.width, opts.height)

    // openExternalLinks
    //this.win.webContents.on('will-navigate', (event, url) => {
    //  if (
    //    url.startsWith('http') &&
    //    !url.match('/auth/authorize') &&
    //    !url.match('/auth/twofactor')
    //  ) {
    //    event.preventDefault()
    //    shell.openExternal(url)
    //  }
    //})

    // Most windows (e.g. onboarding, help...) make the app visible in macOS
    // dock (and cmd+tab) by default. App is hidden when windows is closed to
    // allow per-window visibility.
    if (process.platform === 'darwin') {
      this.app.dock.show()
      const showTime = Date.now()
      this.win.on('closed', () => {
        const hideTime = Date.now()
        setTimeout(() => {
          this.app.dock.hide()
        }, 1000 - (hideTime - showTime))
      })
    }

    // dont keep  hidden windows objects
    this.win.on('closed', () => {
      this.win = null
    })

    const windowCreated = new Promise(resolve => {
      this.win.webContents.on('dom-ready', () => {
        this.win.show()
        resolve(this.win)
      })
    }).catch(err => log.error({ err, sentry: true }, 'failed showing window'))

    this.win.loadURL(this.desktop.config.cozyUrl)

    // devTools
    if (process.env.WATCH === 'true' || process.env.DEBUG === 'true') {
      this.win.webContents.openDevTools({ mode: 'detach' })
    }

    return windowCreated
  }
}
