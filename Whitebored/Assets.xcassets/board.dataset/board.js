(function () {
  var NS = "http://www.w3.org/2000/svg";
  var TUTOR = "#2B4D8C";
  var STUDENT = "#111111";
  var PAD = 14;
  var COL_W = 400;
  var LEFT = 40;
  var RIGHT = 560;

  var measureCtx;

  function inkOf(item) {
    return item && item.ink === "student" ? STUDENT : TUTOR;
  }

  function opts(item, i) {
    return {
      stroke: inkOf(item),
      strokeWidth: 2.2,
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
    var len = 16;
    var p1 = [x2 - len * Math.cos(angle - 0.4), y2 - len * Math.sin(angle - 0.4)];
    var p2 = [x2 - len * Math.cos(angle + 0.4), y2 - len * Math.sin(angle + 0.4)];
    polygon(rc, svg, [[x2, y2], p1, p2], Object.assign({}, o, { fill: o.stroke, fillStyle: "solid" }));
  }

  function arrow(rc, svg, x1, y1, x2, y2, o) {
    var angle = Math.atan2(y2 - y1, x2 - x1);
    var back = 14;
    line(rc, svg, x1, y1, x2 - back * Math.cos(angle), y2 - back * Math.sin(angle), o);
    arrowHead(rc, svg, x1, y1, x2, y2, o);
  }

  function cardsFromShapes(shapes) {
    var left = [];
    var right = [];
    var title = "";
    (shapes || []).forEach(function (s) {
      if (s.type === "box") {
        if (!s.label && !s.sub) return;
        var card = { label: s.label || "", sub: s.sub || "", ink: s.ink };
        ((+s.x || 0) < 500 ? left : right).push(card);
      } else if (s.type === "text" && s.label && !title) {
        title = s.label;
      }
    });
    return {
      title: title,
      left: left,
      right: right,
      layout: left.length && right.length ? "split" : "stack"
    };
  }

  function sceneOf(raw) {
    if (!raw) return { layout: "stack", left: [], right: [] };
    if (raw.layout || raw.figure || raw.left || raw.right || (raw.title && !raw.shapes)) {
      return {
        title: raw.title || "",
        footer: raw.footer || "",
        layout: raw.layout || "stack",
        figure: raw.figure || null,
        left: raw.left || [],
        right: raw.right || []
      };
    }
    if (raw.shapes) return cardsFromShapes(raw.shapes);
    return { layout: "stack", left: [], right: [] };
  }

  function measureCard(card, colW) {
    var inner = colW - PAD * 2;
    var title = wrap(card.label, inner, 20);
    var body = card.sub ? wrap(card.sub, inner, 16) : [];
    var h = PAD * 2 + title.length * 25 + body.length * 20;
    if (title.length && body.length) h += 6;
    return { title: title, body: body, h: Math.max(48, h) };
  }

  function placeCards(cards, colW, top, bottom) {
    var measured = cards.map(function (c) { return measureCard(c, colW); });
    var gap = 12;
    var total = measured.reduce(function (sum, m) { return sum + m.h; }, 0)
      + gap * Math.max(0, measured.length - 1);
    var room = Math.max(48, bottom - top);
    if (total > room && measured.length) {
      var scale = room / total;
      measured.forEach(function (m) { m.h *= scale; });
      gap *= scale;
    }
    var y = top;
    return measured.map(function (m, i) {
      var placed = Object.assign({ y: y }, m, cards[i]);
      y += m.h + gap;
      return placed;
    });
  }

  function drawCard(rc, svg, card, x, w, i) {
    var o = opts(card, i + 4);
    var color = inkOf(card);
    rect(rc, svg, x, card.y, w, card.h, o);
    var titleH = (card.title || []).length * 20 * 1.25;
    var bodyH = (card.body || []).length * 16 * 1.25;
    var block = titleH + (card.body && card.body.length ? 6 + bodyH : 0);
    var cy = card.y + card.h / 2;
    var titleY = card.body && card.body.length ? cy - block / 2 + titleH / 2 : cy;
    labelBlock(svg, card.title, x + w / 2, titleY, color, 20);
    if (card.body && card.body.length) {
      labelBlock(svg, card.body, x + w / 2, titleY + titleH / 2 + 6 + bodyH / 2, color, 16);
    }
  }

  function drawTriangle(rc, svg, pane, fig, o, color) {
    var size = Math.min(pane.w - 120, pane.h - 96, 380);
    var left = pane.x + Math.max(44, (pane.w - size) / 2);
    var top = pane.y + (pane.h - size) / 2 - 6;
    var right = left + size;
    var bottom = top + size;
    var A = [left, top];
    var C = [left, bottom];
    var B = [right, bottom];
    polygon(rc, svg, [A, C, B], filled(o));
    var m = Math.min(28, size * 0.12);
    line(rc, svg, left + m, bottom - m, left + m, bottom, o);
    line(rc, svg, left, bottom - m, left + m, bottom - m, o);
    labelLine(svg, left - 20, (top + bottom) / 2, fig.a || "a", color, 22, "end");
    labelLine(svg, (left + right) / 2, bottom + 24, fig.b || "b", color, 22, "middle");
    labelLine(svg, (left + right) / 2 + 18, (top + bottom) / 2 - 18, fig.c || "c", color, 22, "middle");
  }

  function drawEquation(svg, pane, fig, color) {
    var lines = wrap(fig.label || "", pane.w - 40, 36);
    labelBlock(svg, lines, pane.x + pane.w / 2, pane.y + pane.h / 2, color, 36);
  }

  function drawArrowRow(rc, svg, pane, fig, o, color) {
    var items = (fig.items || []).slice(0, 4);
    var n = items.length;
    if (!n) return;
    var gap = 18;
    var arrowW = 28;
    var inner = pane.w - 32;
    var rawW = n === 1 ? inner : (inner - (n - 1) * (gap + arrowW)) / n;
    var boxW = Math.min(180, Math.max(48, rawW));
    var h = Math.min(88, pane.h - 40);
    var rowW = n * boxW + (n - 1) * (gap + arrowW);
    var x = pane.x + (pane.w - rowW) / 2;
    var y = pane.y + (pane.h - h) / 2;
    items.forEach(function (label, i) {
      rect(rc, svg, x, y, boxW, h, o);
      labelBlock(svg, wrap(label, boxW - 20, 18), x + boxW / 2, y + h / 2, color, 18);
      if (i < n - 1) {
        var x1 = x + boxW + 6;
        var x2 = x + boxW + gap + arrowW - 6;
        arrow(rc, svg, x1, y + h / 2, x2, y + h / 2, o);
      }
      x += boxW + gap + arrowW;
    });
  }

  function drawFigure(rc, svg, pane, fig) {
    if (!fig || !fig.type) return;
    var o = opts(fig, 1);
    var color = inkOf(fig);
    if (fig.type === "right-triangle") drawTriangle(rc, svg, pane, fig, o, color);
    else if (fig.type === "equation") drawEquation(svg, pane, fig, color);
    else if (fig.type === "arrow-row") drawArrowRow(rc, svg, pane, fig, o, color);
  }

  function divider(svg, y1, y2, color) {
    add(svg, native("line", {
      x1: 500, y1: y1, x2: 500, y2: y2,
      stroke: color, "stroke-width": 1.6, "stroke-dasharray": "7 10"
    }));
  }

  window.renderBoard = function (raw) {
    var svg = document.getElementById("pic");
    if (!svg) return;
    while (svg.firstChild) svg.removeChild(svg.firstChild);
    var rc = typeof rough !== "undefined" ? rough.svg(svg) : null;
    var scene = sceneOf(raw);
    var left = scene.left || [];
    var right = scene.right || [];
    var fig = scene.figure;
    var layout = scene.layout;
    if (fig && fig.type) layout = "figure";
    else if (left.length && right.length) layout = "split";
    else layout = "stack";

    var titleLines = wrap(scene.title, 880, 26);
    var top = titleLines.length ? 36 + titleLines.length * 32 + 10 : 48;
    var bottom = scene.footer ? 640 : 668;
    if (titleLines.length) {
      labelBlock(svg, titleLines, 500, 28 + titleLines.length * 16, TUTOR, 26);
    }
    if (scene.footer) {
      labelBlock(svg, wrap(scene.footer, 880, 18).slice(0, 2), 500, 682, TUTOR, 18);
    }

    if (layout === "figure") {
      var cards = right.length ? right : left;
      if (cards.length) {
        drawFigure(rc, svg, { x: 40, y: top, w: 420, h: bottom - top }, fig);
        divider(svg, top - 4, bottom, TUTOR);
        placeCards(cards, COL_W, top, bottom).forEach(function (card, i) {
          drawCard(rc, svg, card, RIGHT, COL_W, i);
        });
      } else {
        drawFigure(rc, svg, { x: 80, y: top, w: 840, h: bottom - top }, fig);
      }
      return;
    }

    if (layout === "split") {
      divider(svg, top - 4, bottom, TUTOR);
      placeCards(left, COL_W, top, bottom).forEach(function (card, i) {
        drawCard(rc, svg, card, LEFT, COL_W, i);
      });
      placeCards(right, COL_W, top, bottom).forEach(function (card, i) {
        drawCard(rc, svg, card, RIGHT, COL_W, i + left.length);
      });
      return;
    }

    var all = left.concat(right);
    var stackW = 520;
    var stackX = (1000 - stackW) / 2;
    placeCards(all, stackW, top, bottom).forEach(function (card, i) {
      drawCard(rc, svg, card, stackX, stackW, i);
    });
  };
})();
