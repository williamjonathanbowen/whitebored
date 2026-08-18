(function () {
  var NS = "http://www.w3.org/2000/svg";
  var TUTOR = "#2B4D8C";
  var STUDENT = "#111111";
  var LEFT = 40;
  var RIGHT = 560;
  var COL_W = 400;
  var TOP = 92;
  var BOTTOM = 668;
  var PAD = 14;

  var measureCtx;

  function ink(shape) {
    return shape.ink === "student" ? STUDENT : TUTOR;
  }

  function opts(shape, i) {
    return {
      stroke: ink(shape),
      strokeWidth: shape.weight === "thick" ? 5 : 2.2,
      roughness: 0.55,
      bowing: 0.55,
      seed: i + 1,
      fill: "transparent",
      fillStyle: "solid",
      preserveVertices: true
    };
  }

  function add(svg, node) {
    if (node) svg.appendChild(node);
  }

  function native(name, attrs) {
    var el = document.createElementNS(NS, name);
    Object.keys(attrs).forEach(function (k) {
      el.setAttribute(k, attrs[k]);
    });
    return el;
  }

  function widthOf(text, size) {
    if (!measureCtx) measureCtx = document.createElement("canvas").getContext("2d");
    measureCtx.font = size + 'px "New York", "Times New Roman", serif';
    return measureCtx.measureText(text).width;
  }

  function wrap(text, maxWidth, size) {
    var raw = String(text || "").replace(/\s+/g, " ").trim();
    if (!raw) return [];
    var words = raw.split(" ");
    var lines = [];
    var cur = "";
    for (var i = 0; i < words.length; i++) {
      var word = words[i];
      var next = cur ? cur + " " + word : word;
      if (cur && widthOf(next, size) > maxWidth) {
        lines.push(cur);
        cur = word;
        while (widthOf(cur, size) > maxWidth && cur.length > 4) {
          var cut = Math.max(4, Math.floor(cur.length * maxWidth / widthOf(cur, size)) - 1);
          lines.push(cur.slice(0, cut) + "–");
          cur = cur.slice(cut);
        }
      } else {
        cur = next;
      }
    }
    if (cur) lines.push(cur);
    return lines.slice(0, 4);
  }

  function labelLine(svg, x, y, str, fill, size, anchor) {
    var el = document.createElementNS(NS, "text");
    el.setAttribute("x", x);
    el.setAttribute("y", y);
    el.setAttribute("fill", fill);
    el.setAttribute("font-size", size);
    el.setAttribute("font-family", '"New York", "Times New Roman", serif');
    el.setAttribute("text-anchor", anchor || "middle");
    el.setAttribute("dominant-baseline", "middle");
    el.textContent = str;
    svg.appendChild(el);
  }

  function labelBlock(svg, lines, cx, cy, fill, size, anchor) {
    if (!lines || !lines.length) return;
    var lh = size * 1.25;
    var top = cy - ((lines.length - 1) * lh) / 2;
    lines.forEach(function (line, i) {
      labelLine(svg, cx, top + i * lh, line, fill, size, anchor);
    });
  }

  function line(rc, svg, x1, y1, x2, y2, o) {
    if (rc) add(svg, rc.line(x1, y1, x2, y2, o));
    else add(svg, native("line", {
      x1: x1, y1: y1, x2: x2, y2: y2,
      stroke: o.stroke, "stroke-width": o.strokeWidth, "stroke-linecap": "round"
    }));
  }

  function filled(o) {
    return Object.assign({}, o, { fill: "#fff", fillStyle: "solid" });
  }

  function rect(rc, svg, x, y, w, h, o) {
    if (rc) add(svg, rc.rectangle(x, y, w, h, filled(o)));
    else add(svg, native("rect", {
      x: x, y: y, width: w, height: h, rx: 10,
      fill: "#fff", stroke: o.stroke, "stroke-width": o.strokeWidth
    }));
  }

  function circle(rc, svg, x, y, d, o, paint) {
    var style = paint || filled(o);
    if (rc) add(svg, rc.circle(x, y, d, style));
    else add(svg, native("circle", {
      cx: x, cy: y, r: d / 2,
      fill: style.fill === "transparent" ? "none" : (style.fill || "#fff"),
      stroke: o.stroke, "stroke-width": o.strokeWidth
    }));
  }

  function ellipse(rc, svg, x, y, w, h, o) {
    if (rc) add(svg, rc.ellipse(x, y, w, h, filled(o)));
    else add(svg, native("ellipse", {
      cx: x, cy: y, rx: w / 2, ry: h / 2,
      fill: "#fff", stroke: o.stroke, "stroke-width": o.strokeWidth
    }));
  }

  function polygon(rc, svg, points, o) {
    if (rc) add(svg, rc.polygon(points, o));
    else add(svg, native("polygon", {
      points: points.map(function (p) { return p[0] + "," + p[1]; }).join(" "),
      fill: o.fill && o.fill !== "transparent" ? o.fill : "none",
      stroke: o.stroke, "stroke-width": o.strokeWidth
    }));
  }

  function arrowHead(rc, svg, x1, y1, x2, y2, o) {
    var angle = Math.atan2(y2 - y1, x2 - x1);
    var len = o.strokeWidth > 3 ? 22 : 16;
    var p1 = [x2 - len * Math.cos(angle - 0.4), y2 - len * Math.sin(angle - 0.4)];
    var p2 = [x2 - len * Math.cos(angle + 0.4), y2 - len * Math.sin(angle + 0.4)];
    polygon(rc, svg, [[x2, y2], p1, p2], Object.assign({}, o, { fill: o.stroke, fillStyle: "solid" }));
  }

  function arrow(rc, svg, x1, y1, x2, y2, o) {
    var angle = Math.atan2(y2 - y1, x2 - x1);
    var back = o.strokeWidth > 3 ? 18 : 14;
    line(rc, svg, x1, y1, x2 - back * Math.cos(angle), y2 - back * Math.sin(angle), o);
    arrowHead(rc, svg, x1, y1, x2, y2, o);
  }

  function cloud(rc, svg, x, y, w, h, o) {
    var d = [
      "M", x + w * 0.25, y + h * 0.72,
      "C", x + w * 0.02, y + h * 0.72, x + w * 0.02, y + h * 0.38, x + w * 0.28, y + h * 0.38,
      "C", x + w * 0.32, y + h * 0.12, x + w * 0.62, y + h * 0.12, x + w * 0.68, y + h * 0.38,
      "C", x + w * 0.98, y + h * 0.32, x + w * 0.98, y + h * 0.72, x + w * 0.72, y + h * 0.72,
      "Z"
    ].join(" ");
    if (rc) add(svg, rc.path(d, filled(o)));
    else add(svg, native("path", { d: d, fill: "#fff", stroke: o.stroke, "stroke-width": o.strokeWidth }));
  }

  function markX(rc, svg, x, y, r, o) {
    line(rc, svg, x - r, y - r, x + r, y + r, o);
    line(rc, svg, x + r, y - r, x - r, y + r, o);
  }

  function markPlus(rc, svg, x, y, r, o) {
    line(rc, svg, x - r, y, x + r, y, o);
    line(rc, svg, x, y - r, x, y + r, o);
  }

  function markCheck(rc, svg, x, y, r, o) {
    line(rc, svg, x - r, y, x - r * 0.2, y + r * 0.55, o);
    line(rc, svg, x - r * 0.2, y + r * 0.55, x + r, y - r * 0.55, o);
  }

  function colX(s) {
    var x = +s.x || 0;
    if (s.type === "box" || s.type === "cloud") x += (+s.w || COL_W) / 2;
    return x < 500 ? LEFT : RIGHT;
  }

  function fitBox(s) {
    s.x = colX(s);
    s.w = COL_W;
    var inner = COL_W - PAD * 2;
    var titleSize = 20;
    s._title = wrap(s.label, inner, titleSize);
    s._body = s.sub ? wrap(s.sub, inner, 16) : [];
    var h = PAD * 2 + s._title.length * titleSize * 1.25 + s._body.length * 16 * 1.25;
    if (s._title.length && s._body.length) h += 6;
    s.h = Math.max(44, h);
    s._titleSize = titleSize;
  }

  function stack(items) {
    items.sort(function (a, b) { return (+a.y || 0) - (+b.y || 0); });
    var y = TOP;
    var gap = 10;
    var total = items.reduce(function (sum, s) { return sum + s.h; }, 0) + gap * Math.max(0, items.length - 1);
    if (total > BOTTOM - TOP && items.length) {
      var scale = (BOTTOM - TOP) / total;
      items.forEach(function (s) { s.h *= scale; });
      gap *= scale;
    }
    items.forEach(function (s) {
      s.y = y;
      y += s.h + gap;
    });
  }

  function layout(shapes) {
    var left = [];
    var right = [];
    var cross = false;
    shapes.forEach(function (s) {
      if (s.type === "box") {
        fitBox(s);
        (s.x === LEFT ? left : right).push(s);
      } else if (s.type === "divider") {
        s.x = 500;
      } else if (s.type === "text") {
        var y = +s.y || 0;
        if (y < 80) {
          s._role = "title";
          s.x = 500;
          s.y = 48;
          s._size = 26;
          s._lines = wrap(s.label, 880, 26).slice(0, 2);
        } else if (y > 620) {
          s._role = "footer";
          s.x = 500;
          s.y = 682;
          s._size = 18;
          s._lines = wrap(s.label, 880, 18).slice(0, 2);
        } else {
          s._role = "heading";
          s.x = colX(s) + COL_W / 2;
          s.y = 72;
          s._size = 18;
          s._lines = wrap(s.label, COL_W, 18).slice(0, 2);
        }
      } else if (s.type === "arrow" || s.type === "line") {
        var a = Math.min(+s.x1 || 0, +s.x2 || 0);
        var b = Math.max(+s.x1 || 0, +s.x2 || 0);
        if (a < 460 && b > 540) {
          s._skip = true;
          cross = true;
        }
      } else if (s.type === "cloud") {
        s.x = colX(s);
        s.w = Math.min(+s.w || 280, COL_W);
        s.h = Math.max(+s.h || 120, 90);
        s._lines = wrap(s.label, s.w - 36, 18);
      } else if (s.type === "circle" || s.type === "ellipse" || s.type === "diamond") {
        var span = s.type === "circle" ? (+s.size || 80) : Math.min(+s.w || 120, COL_W);
        s._lines = wrap(s.label, span * 0.7, 18);
      }
    });
    stack(left);
    stack(right);
    if (cross) {
      shapes.push({
        type: "arrow",
        x1: 468,
        y1: 360,
        x2: 532,
        y2: 360,
        ink: "tutor",
        _bridge: true
      });
    }
  }

  window.renderBoard = function (scene) {
    var svg = document.getElementById("pic");
    if (!svg) return;
    while (svg.firstChild) svg.removeChild(svg.firstChild);
    var rc = typeof rough !== "undefined" ? rough.svg(svg) : null;
    var shapes = ((scene && scene.shapes) || []).map(function (s) {
      return Object.assign({}, s);
    });
    layout(shapes);
    shapes.forEach(function (s, i) {
      if (s._skip) return;
      var o = opts(s, i);
      var color = ink(s);
      var x = +s.x || 0, y = +s.y || 0;
      var w = +s.w || 120, h = +s.h || 56;
      var r = (+s.size || 64) / 2;

      if (s.type === "divider") {
        add(svg, native("line", {
          x1: 500, y1: 36, x2: 500, y2: 664,
          stroke: color, "stroke-width": 1.6, "stroke-dasharray": "7 10"
        }));
      } else if (s.type === "box") {
        rect(rc, svg, x, y, w, h, o);
        var titleH = (s._title || []).length * 20 * 1.25;
        var bodyH = (s._body || []).length * 16 * 1.25;
        var block = titleH + (s._body && s._body.length ? 6 + bodyH : 0);
        var cy = y + h / 2;
        var titleY = s._body && s._body.length ? cy - block / 2 + titleH / 2 : cy;
        labelBlock(svg, s._title, x + w / 2, titleY, color, s._titleSize || 20);
        if (s._body && s._body.length) {
          labelBlock(svg, s._body, x + w / 2, titleY + titleH / 2 + 6 + bodyH / 2, color, 16);
        }
      } else if (s.type === "circle") {
        circle(rc, svg, x, y, +s.size || w || 80, o);
        labelBlock(svg, s._lines, x, y, color, 18);
      } else if (s.type === "ellipse") {
        ellipse(rc, svg, x, y, w, h, o);
        labelBlock(svg, s._lines, x, y, color, 18);
      } else if (s.type === "diamond") {
        polygon(rc, svg, [[x, y - h / 2], [x + w / 2, y], [x, y + h / 2], [x - w / 2, y]], filled(o));
        labelBlock(svg, s._lines, x, y, color, 18);
      } else if (s.type === "line") {
        line(rc, svg, +s.x1 || 0, +s.y1 || 0, +s.x2 || 0, +s.y2 || 0, o);
      } else if (s.type === "arrow") {
        arrow(rc, svg, +s.x1 || 0, +s.y1 || 0, +s.x2 || 0, +s.y2 || 0, o);
      } else if (s.type === "text") {
        labelBlock(svg, s._lines || wrap(s.label, 400, 20), x, y, color, s._size || 20);
      } else if (s.type === "x") {
        markX(rc, svg, x, y, r, o);
      } else if (s.type === "plus") {
        markPlus(rc, svg, x, y, r, o);
      } else if (s.type === "check") {
        markCheck(rc, svg, x, y, r, o);
      } else if (s.type === "dot") {
        circle(rc, svg, x, y, +s.size || 16, o, Object.assign({}, o, { fill: color, fillStyle: "solid" }));
      } else if (s.type === "cloud") {
        cloud(rc, svg, x, y, w, h, o);
        labelBlock(svg, s._lines, x + w / 2, y + h / 2, color, 18);
      }
    });
  };
})();
