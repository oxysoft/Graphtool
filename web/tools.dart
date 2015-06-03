part of graph;

class Tools {
	SelectionTool selection = new SelectionTool();
	MoveTool move = new MoveTool();
	PolylineTool polyline = new PolylineTool();
	QuadraticTool quadratic = new QuadraticTool();
	RadicalSplineTool radicalspline = new RadicalSplineTool();
	EllipseTool ellipse = new EllipseTool();

	Tool get defaultTool => selection;

	Tool fromName(String name) {
		if (name == 'selection') return selection;
		else if (name == 'move') return move;
		else if (name == 'polyline') return polyline;
		else if (name == 'radicalspline') return radicalspline;
		else if (name == 'quadratic') return quadratic;
		else if (name == 'ellipse') return ellipse;
		return null;
	}
}

class ToolStateMachine {
	Tool current;

	ToolStateMachine([Tool start]) {
		change(start);
	}

	void keyUp(int keycode) {
		current.keyUp(keycode);
	}

	void mouseDown(double x, double y, int button) {
		if (current != null)
			current.mouseDown(x, y, button);
	}

	void mouseUp(double x, double y, int button) {
		if (current != null)
			current.mouseUp(x, y, button);
	}

	void mouseMoved(double x, double y) {
		if (current != null)
			current.mouseMoved(x, y);
	}

	bool mouseDragged(double x, double y) {
		return (current != null ? current.mouseDragged(x, y) : false);
	}

	void render() {
		if (current != null)
			current.render();
	}
	
	void change(Tool newstate) {
		var oldstate = current;
		current = newstate;
			
		if (oldstate != null)
			oldstate.leave();
		
		if (newstate != null)
			newstate.enter();
	}
}

abstract class Tool {
	void leave() {
	}

	void enter() {
	}

	void keyUp(int keycode) {
	}

	void mouseDown(double x, double y, int button) {
	}

	void mouseUp(double x, double y, int button) {
	}

	void mouseMoved(double x, double y) {
	}
	
	bool mouseDragged(double x, double y) {
		return false;
	}
	
	void render() {
	}
}

class SelectionTool extends Tool {
	bool down = false;
	Selection selection = new Selection();
	
	double evalEllipse(EllipseGeom geom, double x, double y) {
		return (pow((x - geom.h), 2)  / pow(geom.a, 2)) + (pow((y - geom.k), 2) / pow(geom.b, 2));
	}
	
	List<double> evalEllipseX(EllipseGeom geom, double y) {
		// found with cymath
		double c = sqrt(1 - (pow((y - geom.k), 2) / pow(geom.b, 2)));
		return [geom.a * c + geom.h, geom.a * -c + geom.h];
	}
	
	List<double> evalEllipseY(EllipseGeom geom, double x) {
		// found with cymath
		double c = sqrt(1 - (pow((x - geom.h), 2) / pow(geom.a, 2))); 
		return [geom.b * c + geom.k, geom.b * -c + geom.k];
	}
    				
	var ellipseTest = (num e, Selection sel,  bool x) {
		if (e.isFinite) {
			if (x) return between(e, sel.startx, sel.endx);
			else return between(e, sel.starty, sel.endy);
		}
		
		return false;
	};
	
	List<Function> selected = [];
	
	void updateSelection() {
		selected.clear();
		graph.functions.forEach((Function e) {
			e.color = '#000000';
			
			if (e is EllipseGeom) {
				if (between(e.from, selection.startx, selection.endx) && between(e.to, selection.startx, selection.endx) &&
					 between(e.k - e.b/2, selection.starty, selection.endy) && between(e.k + e.b/2, selection.starty, selection.endy)) {
					selected.add(e);
					return;
				}
				
				print([e.k, e.b, e.k - e.b/2, [selection.starty, selection.endy]]);
				print([between(e.from, selection.startx, selection.endx), between(e.to, selection.startx, selection.endx),
					 between(e.k - e.b/2, selection.endy, selection.starty), between(e.k + e.b/2, selection.endy, selection.starty)]);
				
				if (evalEllipseX(e, selection.starty).any((e) => ellipseTest(e, selection, true)) ||
					evalEllipseX(e, selection.endy).any((e) => ellipseTest(e, selection, true)) ||
					evalEllipseY(e, selection.startx).any((e) => ellipseTest(e, selection, false)) ||
					evalEllipseY(e, selection.endx).any((e) => ellipseTest(e, selection, false)))
					selected.add(e);
				
				return;
			}
			
			double ys = e.eval(selection.startx);
			double ye = e.eval(selection.endx);
			double bs = e.eval(e.from + 0.01);
			double be = e.eval(e.to);
			double lb = min(bs, be);
			double hb = max(bs, be);
			List<double> xs = e.xeval(selection.starty);
			List<double> xe = e.xeval(selection.endy);
			
			// Holy fucking shit
			// it works
			
			if ((e.from < selection.startx && e.to < selection.startx) ||
				(e.from > selection.endx && e.to > selection.endx) ||
				(lb < selection.starty && hb < selection.starty) ||
				(lb > selection.endy && hb > selection.endy)) { 
				return;
			} else {
				if ((between(e.from, selection.startx, selection.endx) && between(e.to, selection.startx, selection.endx) &&
					(between(bs, selection.starty, selection.endy) || bs.isNaN) && (between(be, selection.starty, selection.endy) || be.isNaN))) {
					selected.add(e);
					return;
				}
			}
			
			if (between(xs[0], selection.startx, selection.endx) ||
				between(xe[0], selection.startx, selection.endx) ||
				between(ys, selection.starty, selection.endy) ||
				between(ye, selection.starty, selection.endy))
				selected.add(e);
		});
		
		selected.forEach((e) => e.color = '#ff0000');
	}
	
	void enter() {
		selection.start(0.0, 0.0);
	}
	
	void leave() {
		graph.render();
	}
	
	void mouseDown(double x, double y, int button) {
		if (button != 0)
			return;
		
		down = true;
		selection.start(x, y);
	}
	
	void mouseUp(double x, double y, int button) {
		if (button != 0)
			return;
		
		down = false;
		selection.end(x, y);
		graph.render();
	}
	
	bool mouseDragged(double x, double y) {
		if (!down)
			return false;
		
		selection.end(x, y);
		graph.render();
		
		updateSelection();
		return true;
	}
	
	void render() {
		if (!down)
			return;
		
		c2d.lineWidth = 3;
		c2d.strokeStyle = '#57B0C7';
		num xs = graph.pttopx_x(selection.startx);
		num ys = graph.pttopx_y(selection.starty);
		num xe = graph.pttopx_x(selection.endx);
		num ye = graph.pttopx_y(selection.endy);
		num w = xe - xs;
		num h = ye - ys;
//		c2d.strokeRect(xs, ys, w, h);
		c2d.lineJoin = 'round';
		c2d.setLineDash([10.0, 5.0]);
		c2d.strokeRect(xs, ys, w, h);
		c2d.setLineDash([]);
	}
}

class MoveTool extends Tool {
	bool down = false;
	double xo, yo;
	
	void mouseDown(double x, double y, int button) {
		if (button != 0)
			return;
		
		xo = x;
		yo = y;
		
		down = true;
	}
	
	bool mouseDragged(double x, double y) {
		if (!down)
			return false;
		
		if (tools.selection.selected.isEmpty)
			return false;
		
		double dx = x - xo;
		double dy = y - yo;
		
		tools.selection.selected.forEach((Function e) {
			e.anchors.forEach((a) {
				a.point[0] += dx;
				a.point[1] += dy;
			});
			
			hasChanges = true;
			e.updateEquation();
		});
		
		xo = x;
		yo = y;

		graph.render();
		
		return true;
	}
	
	void mouseUp(double x, double y, int button) {
		if (button != 0)
			return;
		
		down = false;
	}
}

class PolylineTool extends Tool {
	AffineFunction function;
	AffineFunction old;

	void enter() {
		old = null;
		function = null;
	}
	
	void leave() {
		old = null;
		function = null;
	}

	void mouseUp(double x, double y, int button) {
		if (button == 2) {
			function = null;
			graph.render();
			return;
		}
		
		old = function;

		// print([graph.functions.lenAbsolute, group.len]);
		// print(graph.functions[0] == group);

		function = new AffineFunction('#000000');

		function.aa.x = x;
		function.aa.y = y;
		function.ab.x = x;
		function.ab.y = y;

		function.updateEquation();

		graph.functions << function;
		graph.render();
	}

	bool mouseDragged(double x, double y) {
		mouseMoved(x, y);
		
		return true;
	}

	void mouseMoved(double x, double y) {
		if (function == null)
			return;

		function.ab.x = x;
		function.ab.y = y;
		function.updateEquation();
		
		if (old != null) {
//			print(old);
//			function.setIntersection(old);
		}
		
		hasChanges = true;
		graph.render();
	}
}

class RadicalSplineTool extends Tool {
	SquareRootFunction function;

	void mouseUp(double x, double y, int button) {
		if (button == 2) {
			function = null;
			graph.render();
			return;
		}

		function = new SquareRootFunction('#000000');
		
		function.aa.x = x;
		function.aa.y = y;
		function.ab.x = x;
		function.ab.y = y;

		function.updateEquation();
		
		graph.functions << function;
		graph.render();
	}

	bool mouseDragged(double x, double y) {
		mouseMoved(x, y);

		return true;
	}

	void mouseMoved(double x, double y) {
		if (function == null)
			return;

		function.ab.x = x;
		function.ab.y = y;
	
		function.updateEquation();
		hasChanges = true;
		graph.render();
	}
}

class QuadraticTool extends Tool {
	List<double> points = [];
	QuadraticFunction proxy = new QuadraticFunction('#000000');
	
	void leave() {
		points.clear();
		graph.functions.list.remove(proxy);
	}
	
	void mouseMoved(double x, double y) {
		if (points.length == 2 * 2) {
			proxy.ac.x = x;
    		proxy.ac.y = y;
    		proxy.updateEquation();
    		graph.render();
		}
	}
	
	void mouseUp(double x, double y, int button) {
		if (button != 0)
			return;
		
		points.add(x);
		points.add(y);
		
		if (points.length == 2 * 2) {
			proxy.aa.x = points[0];
    		proxy.aa.y = points[1];
    		proxy.ab.x = points[2];
    		proxy.ab.y = points[3];
    		graph.functions << proxy;
		}
		
		if (points.length == 3 * 2) {
			// 3 points, we create the function
			QuadraticFunction f = new QuadraticFunction('#000000');
			
			f.aa.set(proxy.aa.x, proxy.aa.y);
			f.ab.set(proxy.ab.x, proxy.ab.y);
			f.ac.set(x, y);
			f.updateEquation();
			
			graph.functions.list.remove(proxy);
			graph.functions << f;
			
			points.clear();
		}
		
		graph.render();
	}
	
	void render() {
		for (int i = 0; i < points.length; i += 2) {
			double px = points[i + 0];
			double py = points[i + 1];
			
			c2d.fillStyle = 'blue';
                    		
    		double xx = -((graph.xmin - px) / graph.xrange) * SCREEN_W;
    		double yy = -((graph.ymin - py) / graph.yrange) * SCREEN_H;
    		yy = -yy;
    		
    		yy += SCREEN_H;
    		
    		double nsize = 6.0;
    		c2d.fillRect(xx - nsize/2, yy - nsize / 2, nsize, nsize);
		}
	}
}

class EllipseTool extends Tool {
	EllipseGeom geom;
	bool circle = false;
	bool moved = false;

	void mouseDown(double x, double y, int button) {
		if (button != 0)
			return;
		
		if (!circle)
			geom = new EllipseGeom(x, y, 0.0, 0.0, '#000000');
		else
			geom = new CircleGeom(x, y, 0.0, '#000000');
		
		graph.functions << geom;
	}
	
	void mouseUp(double x, double y, int button) {
		if (!moved)
			graph.functions.list.remove(geom);
	}

	bool mouseDragged(double x, double y) {
		if (!mouseButtons[0])
			return false;
		
		moved = true;
	
		if (geom is CircleGeom)
			(geom as CircleGeom).ab.set(x, y);
		else {
			geom.ch.wide = geom.h - x;
            geom.cv.high = geom.k - y;
		}
		
		geom.from = geom.h - geom.wide/2;
		geom.to = geom.h + geom.wide/2;

		geom.updateEquation();
		hasChanges = true;
		graph.render();

		return true;
	}
}