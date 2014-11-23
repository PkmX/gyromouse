package pkmx.gyromouse

import java.net.{SocketException, InetSocketAddress, DatagramPacket, DatagramSocket}

import android.app.{Service, PendingIntent, Notification}
import android.content.Intent
import android.graphics.Color
import android.hardware.{SensorEvent, SensorEventListener, Sensor}
import android.os.{AsyncTask, Bundle}
import android.text.InputType
import android.view.Gravity
import org.scaloid.common._
import rx._
import rx.ops._

import scala.concurrent.{Future, ExecutionContext}
import scala.util.Try
import scala.util.control.NonFatal

object Utils {
  implicit val executionContext = ExecutionContext.fromExecutor(AsyncTask.THREAD_POOL_EXECUTOR)

  sealed trait Observable {
    private[this] var obses: List[Obs] = List()

    def observe(obs: Obs): Obs = {
      obses = obs :: obses
      obs
    }
  }
}

import Utils._

object GyroMouseService {
  sealed trait State
  case class Enabled(ip: String, port: Int) extends State
  case object Disabled extends State
}

class GyroMouseService extends LocalService with Observable {
  import GyroMouseService._
  override implicit val loggerTag = LoggerTag("gyromouse")

  val state = Var[State](Disabled)

  override def onCreate() {
    val gyroSensor = sensorManager.getDefaultSensor(Sensor.TYPE_GYROSCOPE)
    var gyroListener: Option[SensorEventListener] = None

    observe { state foreach {
      case Enabled(ip, port) =>
        Future {
          val socket = new DatagramSocket
          socket.connect(new InetSocketAddress(ip, port))

          gyroListener = Option(new SensorEventListener {
            override def onSensorChanged(event: SensorEvent) {
              val bytes = s"${event.values(0)} ${event.values(1)} ${event.values(2)}\n".getBytes
              val data = new DatagramPacket(bytes, bytes.length)
              try { socket.send(data) } catch {
                case e: SocketException =>
                  e.printStackTrace()
                  state() = Disabled
              }
            }

            override def onAccuracyChanged(sensor: Sensor, accuracy: Int) {}
          })

          val notification =
            new Notification.Builder(this)
              .setSmallIcon(R.drawable.ic_notification_icon)
              .setContentTitle("GyroMouse")
              .setContentText(s"Sending to $ip:$port")
              .setContentIntent {
              val intent = SIntent[MainActivity]
              intent.setFlags(Intent.FLAG_ACTIVITY_CLEAR_TASK | Intent.FLAG_ACTIVITY_NEW_TASK)
              PendingIntent.getActivity(this, 0, intent, PendingIntent.FLAG_UPDATE_CURRENT)
            }.build()

          for { l <- gyroListener } {
            sensorManager.registerListener(l, gyroSensor, 30000)
            notificationManager.notify(0, notification)
            startForeground(0, notification)
          }

        } onFailure { case NonFatal(e) => state() = Disabled }
      case Disabled =>
        for { l <- gyroListener } {
          sensorManager.unregisterListener(l, gyroSensor)
          gyroListener = None
        }
        notificationManager.cancel(0)
        stopForeground(true)
    }}
  }

  override def onStartCommand(intent: Intent, flags: Int, startId: Int): Int = Service.START_STICKY
}

class MainActivity extends SActivity {
  import GyroMouseService._
  override implicit val loggerTag = LoggerTag("gyromouse")

  override def onCreate(savedInstanceState: Bundle) {
    super.onCreate(savedInstanceState)

    startService(SIntent[GyroMouseService])

    new LocalServiceConnection[GyroMouseService] apply { gs =>
      contentView = new SRelativeLayout {
        backgroundColor = Color.parseColor("#2196f3")

        val logo = new STextView {
          text = "GyroMouse"
          textSize = 56.sp
          textColor = Color.parseColor("#dfffffff")
        }

        val ipField = new SEditText { minWidth = 200.sp ; hint = "192.168.1.1" }
        val colon = new STextView { text = ":" }
        val portField = new SEditText { inputType = InputType.TYPE_CLASS_NUMBER ; minWidth = 60.sp ; hint = "5555" }
        val l = new SLinearLayout {
          gravity = Gravity.CENTER
          += (ipField.wrap)
          += (colon.wrap)
          += (portField.wrap)
        }

        val button = new SButton with Observable {
          observe { gs.state foreach { s => text = if (s.isInstanceOf[Enabled]) "DISABLE" else "ENABLE" } }
          setElevation(1.dip)
          onClick {
            gs.state() match {
              case _: Enabled => gs.state() = Disabled
              case Disabled => gs.state() = Enabled(ipField.text.toString, Try(portField.text.toString.toInt) getOrElse 5555)
            }
          }
        }

        += (logo.<<.wrap.centerHorizontal.above(l).>>)
        += (l.<<(WRAP_CONTENT, 48.dip).centerHorizontal.above(button).>>)
        += (button.<<.wrap.alignLeft(l).centerVertical.>>)
      }
    }
  }
}
