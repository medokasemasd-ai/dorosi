package com.aboelkasem.dorosi

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import java.util.Calendar

/**
 * Home-screen widget with the current or next lesson.
 *
 * The app stores the coming lessons as JSON (see home_widget_sync.dart) and schedules a redraw at
 * every lesson start and end, so the choice of lesson is made here at draw time.
 */
class NextLessonWidget : HomeWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val now = System.currentTimeMillis()
        val lesson = pickLesson(widgetData.getString("lessons", null), now)

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.next_lesson_widget)
            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )
            if (lesson == null) {
                views.setTextViewText(R.id.widget_label, "دروسي")
                views.setTextViewText(R.id.widget_time, "مفيش حصص")
                views.setViewVisibility(R.id.widget_title, View.GONE)
                views.setTextViewText(R.id.widget_sub, "افتح التطبيق لإضافة الحصص")
            } else {
                val ongoing = lesson.start <= now
                views.setTextViewText(R.id.widget_label, if (ongoing) "الحصة الحالية" else "الحصة الجاية")
                views.setTextViewText(R.id.widget_time, lesson.time)
                views.setViewVisibility(R.id.widget_title, View.VISIBLE)
                views.setTextViewText(R.id.widget_title, lesson.title)
                val day = dayLabel(lesson.start, now, lesson.dayName)
                views.setTextViewText(
                    R.id.widget_sub,
                    if (lesson.who.isEmpty()) day else "$day · ${lesson.who}",
                )
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }

    private data class Lesson(
        val start: Long,
        val end: Long,
        val title: String,
        val time: String,
        val dayName: String,
        val who: String,
    )

    private fun pickLesson(json: String?, now: Long): Lesson? {
        if (json.isNullOrEmpty()) return null
        return try {
            val arr = JSONArray(json)
            var best: Lesson? = null
            for (i in 0 until arr.length()) {
                val o = arr.getJSONObject(i)
                val l = Lesson(
                    o.getLong("start"),
                    o.getLong("end"),
                    o.optString("title"),
                    o.optString("time"),
                    o.optString("dayName"),
                    o.optString("who"),
                )
                if (l.end > now && (best == null || l.start < best.start)) best = l
            }
            best
        } catch (e: Exception) {
            null
        }
    }

    private fun dayLabel(start: Long, now: Long, dayName: String): String {
        val a = Calendar.getInstance().apply { timeInMillis = start }
        val b = Calendar.getInstance().apply { timeInMillis = now }
        if (a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
            a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
        ) return "اليوم"
        b.add(Calendar.DAY_OF_YEAR, 1)
        if (a.get(Calendar.YEAR) == b.get(Calendar.YEAR) &&
            a.get(Calendar.DAY_OF_YEAR) == b.get(Calendar.DAY_OF_YEAR)
        ) return "بكرة"
        return dayName
    }
}
