expand = function() {
    var span = $(this)
    var id = span.attr("id").match(/\d+/)
    span.unbind("click").text("loading...")
    var td = $(span.parent().get(0))
    var tr = $(td.parent().get(0))
    $.get(
        document.location.href + "?snip=" + id,
        function(data) {
            tr.after(
                $("<tr/>")
                    .addClass("snip")
                    .append(
                        $("<td/>")
                            .addClass("snip")
                            .attr("colspan", td.attr("colspan"))
                            .append(
                                $("<span/>")
                                    .addClass("snip")
                                    .attr("id", span.attr("id") + "s")
                                    .append("(click to fold above)")
                                    .click(fold)
                            )
                    )
            )
            tr.after(data)
            span.text("(click to fold below)").click(fold)
        }
    )
}

fold = function() {
    var id = $(this).attr("id").match(/\d+/)
    var span1 = $("span#snip-" + id)
    var span2 = $("span#snip-" + id + "s")
    var tr2 = $($(span2.parent().get(0)).parent().get(0))
    var trs = $("tr.snip-" + id)

    span1.unbind("click")
    tr2.hide()
    trs.hide()
    span1.text("(click to expand here)").click(function() {
        span1.unbind("click")
        tr2.show()
        trs.show()
        span1.text("(click to fold below)").click(fold)
    })

    var win = $(window)
    var win_h = win.height
    var win_t = win.scrollTop()
    var win_b = win_t + win_h
    var span_h = span1.height()
    var span_t = span1.offset().top
    var span_b = span_t + span_h
    if (span_t < win_t) win.scrollTop(span_t)
    if (span_b > win_b) win.scrollTop(span_b - win_h)
}

filter = function() {
    $("select#filter option:selected").each(function() {
        window.location.replace($(this).attr("value"))
    })
}

acknowledge = function() {
    $("p.acknowledge").append(" / jquery " + $.fn.jquery)
}

$(function() {
  $("span.snip").click(expand)
  $("select#filter").change(filter)
  acknowledge()
})
