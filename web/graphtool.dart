library graph;

import 'dart:html';
import 'dart:math';
import 'dart:js';
import 'dart:convert';
import 'package:math_expressions/math_expressions.dart';
import 'package:vector_math/vector_math.dart';
import 'package:ini/ini.dart';

part 'function.dart';
part 'tools.dart';
part 'settings.dart';
part '3d.dart';
part 'utils.dart';

int SCREEN_W;
int SCREEN_H;

CanvasElement element;
ButtonElement exportButton;
ButtonElement setPictureButton;
ButtonElement addFunctionButton, affineButton, quadraticButton, sqrtButton;
InputElement fileChooserButton;

List<ButtonElement> functionButtons;
List<bool> mouseButtons = [false, false, false];

CanvasRenderingContext2D c2d;
ToolStateMachine statemachine;
Tools tools;

bool hasChanges = false;

Graph graph;
Random rand = new Random();

class Mouse {
	static int x = 0;
	static int y = 0;
}

List<int> getOffset(MouseEvent evt) {
//	  var el = evt.target,
//	      x = 0,
//	      y = 0;
//	
//	  while (el != null && !el.offsetLeft.isNaN && !el.offsetTop.isNaN) {
//		    x += el.offsetLeft - el.scrollLeft;
//		    y += el.offsetTop - el.scrollTop;
//		    el = el.offsetParent;
//	  }
	
	Rectangle rect = element.getBoundingClientRect();
	
	int x = (evt.client.x - rect.left).round();
	int y = (evt.client.y - rect.top).round();
	
	return [x, y];
}

void main() {
	element = querySelector('#graph');
	exportButton = querySelector('#btn-export');
	addFunctionButton = querySelector('#btn-addfunction');
	affineButton = querySelector('#btn-addaffine');
	quadraticButton = querySelector('#btn-addquadratic');
	sqrtButton = querySelector('#btn-addsqrt');
	setPictureButton = querySelector('#btn-setpicture');
	fileChooserButton = querySelector('#btn-importpicture');

	// addFunctionButton.onClick.listen((e) {
	// 	functionButtons.forEach((e) => e.disabled = false);
	// });

	// affineButton.onClick.listen((e) {
	// 	graph.addFunction(1);
	// 	functionButtons.forEach((e) => e.disabled = true);
	// });

	// quadraticButton.onClick.listen((e) {
	// 	graph.addFunction(2);
	// 	functionButtons.forEach((e) => e.disabled = true);
	// });

	// sqrtButton.onClick.listen((e) {
	// 	graph.addFunction(3);
	// 	functionButtons.forEach((e) => e.disabled = true);
	// });

	// functionButtons = [affineButton, quadraticButton, sqrtButton];
	// functionButtons.forEach((e) => e.disabled = true);

	element.style.width = '100%';
	element.style.height = '100%';
	element.width = SCREEN_W = element.clientWidth;
	element.height = SCREEN_H = element.clientHeight;
	element.style.width = null;
	element.style.height = null;
	
	c2d = element.getContext('2d');
	c2d.imageSmoothingEnabled = false;
	graph = new Graph();
	graph.addFunctions();
	int then = new DateTime.now().millisecondsSinceEpoch;
	// print(new DateTime.now().millisecondsSinceEpoch - then);

//	exportButton.onClick.listen((_) => graph.dump());
//	setPictureButton.onClick.listen((_) => fileChooserButton.click());
	fileChooserButton.onChange.listen((e) => graph.setPicture());

	element.onContextMenu.listen((e) => e.preventDefault());
	element.onMouseDown.listen((e) { graph.mouseDown(getOffset(e), e.button); e.preventDefault(); });
	element.onMouseMove.listen((e) { graph.mouseMoved(getOffset(e)); e.preventDefault(); });
	element.onMouseUp.listen((e) { graph.mouseUp(getOffset(e), e.button); e.preventDefault(); });
	element.onMouseWheel.listen((e) => graph.mouseWheel(e.deltaY, e));
	
	window.onResize.listen((e) { graph.resize(); });

	window.onKeyUp.listen((e) => graph.keyReleased(e.keyCode));

	statemachine = new ToolStateMachine();
	tools = new Tools();
	statemachine.change(tools.defaultTool);
	
	graph.render();

	print(new AffineFunction('#000000', 2.323412, 6.71289312).generateEquation());

//	graph.zoom(-3.0);
//	model = new Model(graph);
//	model.load('res/supertoroid.obj');
}

Model model;

class Graph {
	Window window;
	Window startWindow;
	double get xmin => window.xmin;
	double get xmax => window.xmax;
	double get ymin => window.ymin;
	double get ymax => window.ymax;
	void set xmin(double v) { window.xmin = v; }
	void set ymin(double v) { window.ymin = v; }
	void set xmax(double v) { window.xmax = v; }
	void set ymax(double v) { window.ymax = v; }
	int mdx, mdy;
	double unitsPerTick;
	double quality = 0.5;

	double get xrange => xmax - xmin;
	double get yrange => ymax - ymin;
	double get xscl => SCREEN_W / (xmax - xmin);
	double get yscl => SCREEN_H / (ymax - ymin);
	double get xunit => SCREEN_W / xrange;
	double get yunit => SCREEN_H / yrange;

	int get xc => ((xmin / xrange).abs() * SCREEN_W).round();
	int get yc => ((ymin / yrange).abs() * SCREEN_H).round();
	double get xg => 0.015 * SCREEN_W * 2;
	double get yg => 0.015 * SCREEN_H * 2;
	double get iterations => xrange / 1000;

	String axisColor = '#aaaaaa';
	double tickSize = 20.0;
	int charHeight = 8;

	ImageElement backgroundImage;
	double xiscl = 1.0;
	double yiscl = 1.0;
	FunctionGroup functions = new FunctionGroup();

	int lmx = 0, lmy = 0;
	int itn = 0;

	Graph() {
//		window = new Window(-27.44218817, -26.55312141, 29.91725165, 30.80631841);
		window = new Window(-10.0, -10.0, 10.0, 10.0);
		startWindow = window.clone;
		unitsPerTick = 1.0;

		backgroundImage = new ImageElement();
		
//		loadImage();
		setJavascriptExports();
		makeSquare();
		
		xiscl = xscl;
		yiscl = yscl;
	}

	void scale([double size = 1.5]) {
		Matrix4 mat = new Matrix4.identity();
		mat.translate(-0.5, -0.5);
		mat.scale(size, size);
		mat.translate(0.5, 0.5);
		
		Vector3 proxy = new Vector3.zero();
		
		var scaleVector = (Vector2 vec) {
			proxy.x = vec.x;
			proxy.y = vec.y;
			
			proxy = mat * proxy;
			
			vec.x = proxy.x;
			vec.y = proxy.y;
		};
		
		functions.forEach((Function f) {
			f.anchors.forEach((ControlPoint c) {
				scaleVector(c.point);
				
				if (c is HorizontalConstraint) c.wide *= size;
				else if (c is VerticalConstraint) c.high *= size;
				
				f.updateEquation();
			});
		});
		
		render();
	}
	
	void resize() {
		element.style.width = '100%';
    	element.style.height = '100%';
    	element.width = SCREEN_W = element.clientWidth;
    	element.height = SCREEN_H = element.clientHeight;
    	element.style.width = null;
    	element.style.height = null;
    	
    	makeSquare();
    	
    	render();
	}
	
	void makeSquare() {
		double ratio = (SCREEN_H / SCREEN_W);
		double ymid = (ymin + ymax) / 2;
		double dy = ratio * (xmax - xmin);
		ymin = ymid - dy / 2;
		ymax = ymid + dy / 2;
	}
	
	void setJavascriptExports() {
		context['changeTool'] = changeTool;
		context['serializeJson'] = () => JSON.encode(functions.serialize());
		context['deserializeJson'] = (String data) {
			if (data == null || data.isEmpty)
				return;
			
			var decoded = JSON.decode(data);
			functions.deserialize(decoded);
			render();
		};
		context['showSetPicture'] = () => fileChooserButton.click();
		context['exportGrf'] = () {
			HttpRequest.request('/canexport').then((HttpRequest req) {
				var res = JSON.decode(req.response as String);
				
				if (res['result'])
					dump();
			});
		};
		context['addFunction'] = addFunction;
	}

	void changeTool(tool) {
		if (tool is! String)
			return;
		
		tool = tools.fromName(tool);
		statemachine.change(tool);
	}
	
	void setBought(b) {
	}

	void loadImage() {
		ImageElement elem = backgroundImage;
		
		c2d.drawImage(elem, 0, 0);
		int ci = 0;
		ImageData data = c2d.getImageData(0, 0, elem.width, elem.height);
		List<List<List<double>>> scanlines = []; // scanlines of colors in rgb

		for (int j = elem.height; j > 0; j--) {
			List<List<double>> scanline = [];

			for (int i = 0; i < elem.width; i++) {
				int r = data.data[ci];
				int g = data.data[ci+1];
				int b = data.data[ci+2];
				int rgb = r << 16 | g << 8 | b;
				List<double> xyz = rgbToXyz(r, g, b);
				List<double> lab = xyzToLab(xyz[0], xyz[1], xyz[2]);
				lab.add(rgb * 1.0);

				scanline.add(lab);
				ci += 4;
			}
			scanlines.add(scanline);
		}

		ci = 0;

		for (int j = 0; j < scanlines.length; j++) {
			List<List<double>> colors = scanlines[j];

			for (int i = 0; i < colors.length;) {
				List<double> lab = colors[i];
				int col = lab[3].round();
				int len = 1;

				double deltae(lab1, lab2) {
					double dist(double a, double b) {
						return (a - b) * (a - b);
					}

					return sqrt(dist(lab1[0], lab2[0]) + dist(lab1[1], lab2[1]) + dist(lab1[2], lab2[2]));
				}

				for (int scan = i + 1; scan < colors.length; scan++) {
					if (deltae(lab, colors[scan]) > 30)
	   					break;

	   				len++;
				}

				double y = (scanlines.length - j) * 0.1;
				plotLine(i * 0.1, y, (i + len) * 0.1, y, '#${col.toRadixString(16)}');
				i += len;
			}
		}
		
		render();
		print(functions.len);
	}

	void plotPoint(double x, double y, String color) {
		double x1 = x;
		double y1 = y;
		double x2 = x + 0.1;
		double y2 = y1;
		
		double a = (y2 - y1) / (x2 - x1);
		double b = (y2 - a * x2);
		double from = x1;
		double to = x2;
		AffineFunction function = new AffineFunction(color);
		function.a = a;
		function.b = b;
		function.from = from;
		function.to = to;
		function.equation = '$b';
		functions << function;
	}
	
	void plotLine(double x1, double y1, double x2, double y2, String color) {
//		x2 += 0.1;
		
		double a = (y2 - y1) / (x2 - x1);
		double b = (y2 - a * x2);
		double from = x1;
		double to = x2;
		AffineFunction function = new AffineFunction(color);
		function.size = 0.2;
		function.a = a;
		function.b = b;
		function.from = from;
		function.to = to;
		function.equation = '$b';
		functions << function;
	}
	
	void addFunctions() {
//		functions.add(new AffineFunction('#ff0000'));
//		for (int i = 0; i < 10; i++) {
//			functions.add(new QuadraticFunction('#${ (i / 10 * 0xffffff).round().toRadixString(16) }'));
//		}
	}

	void addFunction(int type) {
		print(type);
		Function f;

		switch (type) {
			case 0: // generic
				break;
			case 1: // affine
				f = new AffineFunction('#000000');
				break;
			case 2: // quadratic
				f = new QuadraticFunction('#000000');
				
				if (f is QuadraticFunction) {//so we don't have to case everywhere
					f.aa.set(pxtopt_x(SCREEN_W * 0.25), pxtopt_y(SCREEN_H * 0.75));
					f.ab.set(pxtopt_x(SCREEN_W * 0.60), pxtopt_y(SCREEN_H * 0.50));
					f.ac.set(pxtopt_x(SCREEN_W * 0.75), pxtopt_y(SCREEN_H * 0.25));
					f.updateEquation();
				}
				
				break;
			case 3: // square root
				f = new SquareRootFunction('#000000');
				break;
			case 4: // exponential
				break;
			case 5: // sine
				break;
			case 5: // cosine
				break;
			default:
				return;
		}

		functions << f;
		tools.selection.selected.add(f);
		render();
	}

	void mouseDown(List<int> offs, int button) {
		mouseButtons[button] = true;
		mdx = offs[0];
		mdy = offs[1];
		startWindow = window.clone;

		statemachine.mouseDown(pxtopt_x(offs[0]), pxtopt_y(offs[1]), button);
	}
	
	void mouseUp(List<int> offs, int button) {
		mouseButtons[button] = false;
		statemachine.mouseUp(pxtopt_x(offs[0]), pxtopt_y(offs[1]), button);
	}

	void mouseMoved(List<int> offs) {
		Mouse.x = offs[0];
		Mouse.y = offs[1];
		
//		print([offs[0], offs[1], pxtopt_x(offs[0]), pxtopt_y(offs[1])]);
		var ptx = pxtopt_x(offs[0]);
		var pty = pxtopt_y(offs[1]);

		if (!mouseButtons.any((e) => e)) {
			tools.selection.selected.forEach((f) => f.mouseMoved(ptx, pty));
			statemachine.mouseMoved(ptx, pty);
		} else {
			mouseDragged(offs);
		}

		lmx = offs[0];
		lmy = offs[1];
	}

	void mouseDragged(List<int> offs) {
		bool dragAnchor = false;

		int x = offs[0];
     	int y = offs[1];
		
		double ptlmx = pxtopt_x(lmx);
		double ptlmy = pxtopt_y(lmy);
		double ptmx = pxtopt_x(x);
		double ptmy = pxtopt_y(y);
		double dx = ptmx - ptlmx;
		double dy = ptmy - ptlmy;
		
    	dragAnchor = tools.selection.selected.map((f) => f.mouseDragged(dx, dy)).any((e) => e);

    	if (!dragAnchor)
			statemachine.mouseDragged(pxtopt_x(offs[0]), pxtopt_y(offs[1]));

		if (!dragAnchor && mouseButtons[2]) {
			window.xmin = startWindow.xmin - (x - mdx) / xscl;
			window.xmax = startWindow.xmax - (x - mdx) / xscl;
			window.ymin = startWindow.ymin + (y - mdy) / yscl;
			window.ymax = startWindow.ymax + (y - mdy) / yscl;
			
			render();
		}
	}

	void mouseWheel(num delta, WheelEvent e) {
		if (delta < 0) {
			zoom(0.05, e);
		} else if (delta > 0) { 
			zoom(-0.05, e);
		}
	}
	
	void zoom(num scale, [WheelEvent e = null]) {
		if (e != null) {
			List<int> offs = getOffset(e);
			int mx = offs[0];
			int my = offs[1];
    		double mt = 1 - (my / SCREEN_H);
    		double ml = mx / SCREEN_W;
    		xmin += xrange * scale * ml;
    		xmax -= xrange * scale * (1 - ml);
    		ymin += yrange * scale * mt;
    		ymax -= yrange * scale * (1 - mt);
    		
    		xiscl += scale;
    		yiscl += scale;
		}
		
		startWindow = window.clone;
		render();
	}
	
	void keyReleased(int keycode) {
		if (keycode == KeyCode.A) {
			statemachine.change(tools.polyline);
		} else if (keycode == KeyCode.R) {
			statemachine.change(tools.radicalspline);
		} else if (keycode == KeyCode.Q) {
			statemachine.change(tools.quadratic);
		} else if (keycode == KeyCode.F) {
			statemachine.change(tools.ellipse);
		} else if (keycode == KeyCode.S) {
			statemachine.change(tools.selection);
		} else if (keycode == KeyCode.DELETE) {
			tools.selection.selected.forEach((e) => functions.list.remove(e));
			tools.selection.selected.clear();
			render();
		} else if (keycode == KeyCode.M) {
			statemachine.change(tools.move);
		} else if (keycode == KeyCode.NUM_FOUR) {
			Settings.noSqrt = !Settings.noSqrt;
			print('No sqrt: ${Settings.noSqrt}');
		} else if (keycode == KeyCode.NUM_MINUS) {
			xiscl -= 2.0;
			yiscl -= 2.0;
			render();
		} else if (keycode == KeyCode.NUM_PLUS) {
			xiscl += 2.0;
			yiscl += 2.0;
			render();
		} else if (keycode == KeyCode.NUM_SEVEN) {
			scale(0.8);
		} else if (keycode == KeyCode.NUM_EIGHT) {
			scale(1.2);
		} else if (keycode == KeyCode.E) {
//			dump();
		} else if (keycode == KeyCode.J) {
//			var res = context.callMethod('prompt', ['enter']);
//			var src = JSON.decode(res);
//			functions.deserialize(src);
		}
	 	// else if (keycode == KeyCode.Q) {
		//   addFunction(2);
		// } else if (keycode == KeyCode.P) {
		// 	functions.forEach((f) {
		// 		print(f.generateEquation());
		// 	});
		// }

		statemachine.keyUp(keycode);
	}

	void render() {
		c2d.clearRect(0, 0, SCREEN_W, SCREEN_H);
		c2d.fillStyle = '#ffffff';
		c2d.fillRect(0, 0, SCREEN_W, SCREEN_H);

		//render the background picture
		double xx = (xmin / xrange).abs() * SCREEN_W;
		double yy = (ymin / yrange).abs() * SCREEN_H;
		yy = -yy;
		
		if (xmin > 0 && xmax > 0) 
			xx = -xx;
		if (ymin > 0 && ymax > 0) 
			yy = -yy;
		
		yy += SCREEN_H;
		double xf = xiscl / xscl;
		double yf = yiscl / yscl;
		double ww = backgroundImage.width / xf;
		double hh = backgroundImage.height / yf; 
		
		c2d.globalAlpha = 0.4;
		c2d.drawImageScaled(backgroundImage, 
			xx + 0.5, 
			yy - hh + 0.5,
			ww,
			hh
		);
		c2d.globalAlpha = 1.0;
		
		c2d.lineWidth = 3.0;

		//render grid and functions
		renderGrid();
		tools.selection.selected.forEach((f) => f.renderControls());
		renderFunctions();
		renderTool();
	}
	
	void renderGrid() {
		double xgs, ygs;
		
		double s = 0.000000000001;
		for (int c = 0; xrange/s > xg - 1; c++) {
			if (c % 3 == s) s *= 2.5;
			else s *= 2;
		}
		xgs = s;
		
		s = 0.000000000001;
		for (int c = 0; yrange/s > yg - 1; c++) {
			if (c % 3 == 1) s *= 2.5;
			else s *= 2;
		}
		ygs = s;
		
		c2d.font = "8pt 'Calibri'";
		c2d.textAlign = 'center';
		
		double xcur = (xmin / xgs).floor() * xgs;
		double ycur = (ymin / ygs).floor() * ygs;
		
		double xmaxis = charHeight * 1.5;
		double ymaxis = -1.0;
		
		xcur = floatFix(xcur);
		ycur = floatFix(ycur);
		
		if (ymax >= 0 && ymin <= 0)
			xmaxis = SCREEN_H - ((0 - ymin) / (ymax - ymin)) * SCREEN_H + charHeight * 1.5;
		else if (ymin > 0)
			xmaxis = SCREEN_H - 5.0;
		if (xmaxis > SCREEN_H - (charHeight / 2))
			xmaxis = SCREEN_H - 5.0;
		
		if (xmax >= 0 && xmin <= 0)
			ymaxis = ((0 - xmin) / (xmax - xmin)) * SCREEN_W - 2;
		else if (xmax < 0)
			ymaxis = SCREEN_W - 6.0;
		if (ymaxis < (c2d.measureText('$ycur').width + 1)) {
			ymaxis = -1.0;
		}
		
//		int sigdigs = '$xcur'.length + 3;
		double xaxis, yaxis;
		
		//vertical lines
		for (int i = 0; i < xg; i++) {
			double xp = pttopx_x(xcur);
			if (xp - 0.5 > SCREEN_W + 1 || xp < 0) {
				xcur += xgs;
				continue;
			}
			
//			xcur = floatFix(xcur);
			
			if (xcur.round() == 0)
				xaxis = xp;
			
			c2d.fillStyle = 'rgb(190, 190, 190)';
			c2d.fillRect(xp, 0, 1, SCREEN_H);
			
			c2d.fillStyle = 'rgb(0, 0, 0)';

			if (xcur != 0) {
				var ww = c2d.measureText('${xcur.round()}').width;
				if (xp + ww/2 > SCREEN_W)
					xp = SCREEN_W - ww/2 + 1;
				else if (xp - ww/2 < 0)
					xp = ww/2 + 1;
			
				// c2d.fillText('${xcur.round()}', xp, xmaxis);
			}
			
			xcur += xgs;
		}
		
		//horizontal lines
		for (int i = 0; i < yg; i++) {
			double yp = pttopx_y(ycur);
			if (yp - 0.5 > SCREEN_H + 1 || yp < 0) {
				ycur += ygs;
				continue;
			}
			
			ycur = floatFix(ycur);
			
			if (ycur == 0)
				yaxis = yp;
			
			c2d.fillStyle = 'rgb(190, 190, 190)';
			c2d.fillRect(0, yp, SCREEN_W, 1);
			
			c2d.fillStyle = 'rgb(0, 0, 0)';
			if (ycur != 0) {
				double ww = c2d.measureText('${ycur.round()}').width;
				if (yp + charHeight/2 > SCREEN_H)
					yp = SCREEN_H - charHeight/2 - 1;
				if (yp - ww < 0)
					yp = ww;
				// double xap = ymaxis;
				// if (ymaxis == -1)
				// 	xap = ww;
				// else
				// 	xap -= ww + 1;

				// c2d.fillText('${ycur.round()}', xap, yp + 3);

				// var ww = c2d.measureText('${ycur.round()}').width;
				// if (yp + ww/2 > SCREEN_W)
				// 	yp = SCREEN_W - ww/2 + 1;
				// else if (yp - ww/2 < 0)
				// 	yp = ww/2 + 1;

				// c2d.fillText('${ycur.round()}', ymaxis, yp);
			}
			
			ycur += ygs;
		}
		
		if (xaxis != null)
			c2d.fillRect(xaxis.round() + 0.5, -1, 2, SCREEN_H);
		if (yaxis != null)
			c2d.fillRect(-1, yaxis.round() + 0.5, SCREEN_W, 2);
	}

	void renderFunctions() {
		c2d.save();
		functions.forEach((e) {
			try {
			c2d.strokeStyle = e.color;
			if (e.render())
				return;

			// bool lineExists;
			// double lastPoint = 0.0;

			double tp = SCREEN_W + (1 / quality);
			double xval = 0.0;

			double from = e.from;
			if (e.to == null) {
				if (e.b < 0.0) from = e.h;
				else if (e.b > 0.0) from = e.ab.x;
				
				print(from);
			}
			
			double i = (from - xmin) * xscl;
			double yend = e.eval(from);
			if (yend == null)
				return;
			double yy = SCREEN_H - (yend - ymin) * yscl;

			c2d.beginPath();
			c2d.moveTo(i, yy);
			c2d.lineTo(i, yy);

			for (double i = 0.0; i < tp; i += (1 / quality)) {
				xval = i / xscl + xmin;
				
				if (e.from != null)
					if (xval < e.from)
						continue;
				if (e.to != null)
					if (xval > e.to)
						break; // We can safely break

				double yval = e.eval(xval);

				double yy = SCREEN_H - (yval - ymin) * yscl;

				c2d.lineTo(i, yy);
				c2d.moveTo(i, yy);

				// if (yy >= (SCREEN_H * -1) && yy <= SCREEN_H * 2) { 
				// 	if (lineExists)
				// 		c2d.beginPath();
					
				// 	if (lastPoint != null && ((lastPoint > 0 && yval < 0) || (lastPoint < 0 && yval > 0))) {
				// 		c2d.moveTo(i, yy);
				// 	} else {
				// 		c2d.lineTo(i, yy);
				// 	}
					
				// 	lineExists = false;
				// 	lastPoint = yval;
				// } else if (!lineExists){
				// 	c2d.lineTo(i, yy);
				// 	lastPoint = yval;
				// 	// c2d.stroke();
				// 	lineExists = true;
				// }
			}
			
			double to = e.to;
			if (e.to == null) {
				if (e.b < 0.0) to = e.h;
				else if (e.b > 0.0) to = e.ab.x;
				
				print(to);
			}
				
			
			i = (to - xmin) * xscl;
			yend = e.eval(to);
			yy = SCREEN_H - (yend - ymin) * yscl;

			c2d.lineTo(i, yy);

			c2d.closePath();
			
			c2d.lineWidth = e.size;
			c2d.stroke();
			} catch (e, stack) {
				print(stack);
			}
		});
		c2d.restore();
	}

	void renderTool() {
		if (statemachine != null)
			statemachine.render();
	}
	
	void setPicture([ImageElement elem = null]) {
		if (elem == null) elem = backgroundImage;
		
		if (fileChooserButton.files[0] != null) {
			FileReader reader = new FileReader();

			reader.onLoad.listen((e) {
				elem.src = e.target.result; // = new ImageElement(src: e.target.result);
				render();
			});

			reader.readAsDataUrl(fileChooserButton.files[0]);
		}
	}

	void dump() {
		Config grf = new Config();
        		
        //general stuff
        grf.add_section('Graph');
        grf.set('Graph', 'Version', '4.4.2.543');
        grf.set('Graph', 'MinVersion', '2.5');
        grf.set('Graph', 'OS', 'Windows 7');

        grf.add_section('Axes');
		//x's
        grf.set('Axes', 'xMin', '$xmin');
        grf.set('Axes', 'xMax', '$xmax');
        grf.set('Axes', 'xTickUnit', '${unitsPerTick}');
        grf.set('Axes', 'xGridUnit', '${unitsPerTick}');
		//y's
        grf.set('Axes', 'yMin', '$ymin');
        grf.set('Axes', 'yMax', '$ymax');
        grf.set('Axes', 'yTickUnit', '${unitsPerTick}');
        grf.set('Axes', 'yGridUnit', '${unitsPerTick}');
		//etc.
        grf.set('Axes', 'AxesColor', 'clBlue'); // Default from Graph
        grf.set('Axes', 'GridColor', '0x00FF9999'); // Default from Graph
        grf.set('Axes', 'ShowLegend', '0'); // Default from Graph
        grf.set('Axes', 'Radian', '1'); // ?

        Map<String, int> ids = {
        	'functions' : 1, // Graph counts functions from 1 it would seem
        	'relations' : 1,
        }; 

        functions.forEach((Function e) {
        	int i = ids['functions'];
        	grf.add_section('Func$i');
        	ids['functions']++;
        	
        	try {
	        	if (e.serializeGrf(grf, ids))
	        		return;
	        	
	        	grf.set('Func$i', 'FuncType', '0');
	        	grf.set('Func$i', 'y', '${e.generateEquation()}');
	        	
	        	int dd = 0;
	
	        	// adjust when dealing with high values
	        	if (e is AffineFunction)
	        		dd += (e.a.abs() / 5.0).floor();
	    		if (e is SquareRootFunction)
	        		dd += (e.a.abs() / 4.0).floor();
	
	        	dd += postRoundFactor;
	
	        	if (e is! SquareRootFunction || (e is SquareRootFunction && e.b < 0.0))
	        		grf.set('Func$i', 'From', '${round(e.from, dd)}');
	        	if (e is! SquareRootFunction || (e is SquareRootFunction && e.b > 0.0))
	        		grf.set('Func$i', 'To', '${round(e.to, dd)}');
	        	// Graph uses bgr format. fuck bgr
	        	int bgr = rgbStringToBgr(e.color);
	        	grf.set('Func$i', 'Color', '0x${bgr.toRadixString(16)}');
	        	grf.set('Func$i', 'Size', '${e.size}');
        	} catch (error) {
        		e.color = '#ff00ff';
        		render();
        		print('couldn\'t export a function: $error');
        	}
        });

        int funcCount = ids['functions'];
        int relCount = ids['relations'];

        grf.add_section('Data'); // Most of the stuff in here, if not all, is just counts
        grf.set('Data', 'TextLabelCount', '0');
        grf.set('Data', 'FuncCount', '$funcCount');
        grf.set('Data', 'PointSeriesCount', '0');
        grf.set('Data', 'ShadeCount', '0');
        grf.set('Data', 'RelationCount', '$relCount');
        grf.set('Data', 'OleObjectCount', '0'); // wtf is this
        //

        download('file.grf', grf.toString());
		
		// exportButton.value = '';
		// exportButton.type = "text";
		// exportButton.type = "file";
	}
	
	double pxtopt_x(num x) {
		return x/xscl + xmin;
    }

    double pxtopt_y(num y) {
    	return ymin - (y - SCREEN_H) / yscl;
    }
	
	double pttopx_x(num x) {
    	return xscl * (x - xmin);
    }

    double pttopx_y(num y) {
    	return -yscl*y + yscl*ymin + SCREEN_H;
    }
    
  
}

class Window {
	double xmin, ymin;
	double xmax, ymax;
	
	Window(this.xmin, this.ymin, this.xmax, this.ymax);
	
	Window get clone => new Window(xmin, ymin, xmax, ymax);
	
	String toString() {
		return 'Window=[xmin: $xmin, ymin: $ymin, xmax: $xmax, ymax: $ymax]';
	}
}

void download(String filename, String data) {
	var elem = document.createElement('a');
	elem.setAttribute('href', 'data:text/plain;charsest=utf-8,${Uri.encodeComponent(data)}');
	elem.setAttribute('download', filename);
	elem.click();
}

double floatFix(double v, [int factor = 10000000000]) {
	if (!v.isFinite) // a pleasant workaround
		return v;
	
	return (v * factor).round() / factor;
}

double round(double v, [int factor = 2]) {
	if (!v.isFinite) // a pleasant workaround
		return v;
	
	int ten = pow(10, factor);
	
	return (v * ten).round() / ten;
}

List<double> rgbToXyz(r, g, b) {
	r = r / 255;
	g = g / 255;
	b = b / 255;

	if (r > 0.04045 ) r = pow((( r + 0.055 ) / 1.055 ), 2.4);
    else r = r / 12.92;
    if (g > 0.04045 ) g = pow((( g + 0.055 ) / 1.055 ), 2.4);
    else g = g / 12.92;
    if (b > 0.04045 ) b = pow((( b + 0.055 ) / 1.055 ), 2.4);
    else b = b / 12.92;

    r = r * 100;
    g = g * 100;
    b = b * 100;

    //Observer. = 2°, Illuminant = D65
    double X = r * 0.4124 + g * 0.3576 + b * 0.1805;
    double Y = r * 0.2126 + g * 0.7152 + b * 0.0722;
    double Z = r * 0.0193 + g * 0.1192 + b * 0.9505;

	return [X, Y, Z];
}

List<double> xyzToLab(x, y, z) {
	var ref_X =  95.047;
    var ref_Y = 100.000;
    var ref_Z = 108.883;

    double var_X = x / ref_X;          //ref_X =  95.047   Observer= 2°, Illuminant= D65
    double var_Y = y / ref_Y;          //ref_Y = 100.000
    double var_Z = z / ref_Z;          //ref_Z = 108.883

    if (var_X > 0.008856) var_X = pow(var_X,(1/3));
    else var_X = (7.787 * var_X) + (16 / 116);
    if (var_Y > 0.008856) var_Y = pow(var_Y,(1/3));
    else var_Y = (7.787 * var_Y) + (16 / 116);
    if (var_Z > 0.008856) var_Z = pow(var_Z,(1/3));
    else var_Z = (7.787 * var_Z) + (16 / 116);

    double CIE_L = ( 116 * var_Y ) - 16;
    double CIE_a = 500 * ( var_X - var_Y );
    double CIE_b = 200 * ( var_Y - var_Z );

	return [CIE_L, CIE_a, CIE_b];
}

int rgbStringToBgr(String rgbstring) {
	int color = int.parse(rgbstring.substring(1), radix:16);
	return (color & 0xff) << 16 | ((color >> 8) & 0xff) << 8 | (color >> 16) & 0xff;
}

bool isNumeric(String s) {
	if(s == null) {
		return false;
	}
	return double.parse(s, (e) => null) != null;
}