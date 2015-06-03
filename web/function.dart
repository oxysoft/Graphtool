part of graph;

Parser parser = new Parser();
int roundFactor = 6;
int postRoundFactor = 2;

abstract class FunctionContainer {
	List<FunctionContainer> get functions;
	
	Object serialize();
}

class FunctionGroup extends FunctionContainer {
	List<Function> list = [];

	operator [](int v) {
		if (v < 0)
			v = len - v - 1;

		return list[v];
	}

	operator []=(int v, f) {
		list[v] = f;
	}

	operator <<(v) {
		if (v is FunctionContainer)
			list.add(v);
	}

	operator >>(v) {
		if (v is FunctionContainer)
			
			list.remove(v);
	}

	void removeAll(List rem) {
		List<FunctionGroup> stack = [];
		stack.add(this);
		
		while (stack.length > 0) {
			FunctionGroup group = stack.removeLast();
			rem.forEach((e) {
				if (e is FunctionGroup)
					stack.add(e);
				else
					group.list.remove(e);
			});
		}
	}
	
	int get len => list.length;

	int get lenAbsolute {
		List<FunctionContainer> stack = [];
		stack.add(this);
		FunctionContainer current;
		int i = 0;

		while (stack.length > 0) {
			i++;
			current = stack.removeAt(0);
			stack.addAll(current.functions.where((c) => c != current));
		}

		return i;
	}

	List<FunctionContainer> get functions => list;

	Object serialize() {
		List data = [];
		
		forEach((e) {
			data.add(e.serialize());
		});
		
		return ({ 'functions' : data });
	}
	
	void deserialize(Map root) {
		root['functions'].forEach((List v) {
			FunctionContainer f = null;
			
			String type = v[0];
			
			if (type == 'generic') f = new Function.deserialize(v);
			else if (type == 'ellipse') f = new EllipseGeom.deserialize(v);
			else if (type == 'circle') f = new CircleGeom.deserialize(v);
			else if (type == 'affine') f = new AffineFunction.deserialize(v);
			else if (type == 'quadratic') f = new QuadraticFunction.deserialize(v);
			else if (type == 'sqrt') f = new SquareRootFunction.deserialize(v);
			else throw 'Unhandled function type';
			
			if (f is Function)
				f.updateEquation();
			
			this << f;
		});
	}
	
	// we'll want to traverse it recursively most of the time, we make it the default
	// also we assume that callback is a dart Function. we can't type it so because we
	// define our own mathematical Function class
	void forEach(callback, [bool recursive = true]) {
		list.forEach((e) {
			if (e is Function) {
				callback(e);
			} else if (e is FunctionGroup) {
				if (recursive) {
					(e as FunctionGroup).forEach(callback, true);
				}
			}
		});
	}
}

class Function extends FunctionContainer {
	String equation;
	double size;
	double from, to;
	String color;
	List<double> data = [];

	Function.generic() {
		size = 3.0;
	}
	
	Function.deserialize(List list) {
		// type is 0
		equation = list[1];
		from = list[2];
		to = list[3];
		size = list[4];
		color = list[5];
	}
	
	Function(this.equation, this.color) {
//		from = graph.xmin;
//		to = graph.xmax;
		from = -5.0;
		to = 5.0;
		size = 3.0;
	}
	
	List<ControlPoint> get anchors => [];

	double eval(num x) {
		Expression exp = parser.parse(equation);
		ContextModel cm = new ContextModel();
		cm.bindVariable(new Variable('x'), new Number(x));
		double y = exp.evaluate(EvaluationType.REAL, cm);
		return y;
	}
	
	List<double> xeval(double y) {
		return [0.0];
	}

	bool render() {
		return false;
	}

	void renderControls() {
	}

	void mouseMoved(double x, double y) {
	}

	bool mouseDragged(double x, double y) {
		return false;
	}

	void updateEquation() {
		equation = generateEquation();
	}

	// function of any type, no smart anchors or anything
	String generateEquation() {
		return equation;
	}

	bool serializeGrf(Config grf, Map<String, int> ids) {
		return false;
	}
	
	Object serialize() {
		return [
			'generic',
			equation,
			from,
			to,
			size,
			color
		];
	}

	void scale(Vector2 target) {
	}

	List<FunctionContainer> get functions => [this];
}

class EllipseGeom extends Function {
	Anchor aa;
	VerticalConstraint cv;
	HorizontalConstraint ch;

	double h, k;
	double wide, high;

	// mathematical aliases
	double get a => wide.abs();
	double get b => high.abs();
	
	EllipseGeom.deserialize(List data) : super.generic() {
		aa = new Anchor.deserialize(this, data[1][0]);
		cv = new VerticalConstraint.deserialize(this, data[1][1]);
		ch = new HorizontalConstraint.deserialize(this, data[1][2]);
		
		size = data[2] * 1.0;
		color = data[3];
		
		updateEquation();
	}
	
	EllipseGeom(double x, double y, double wide, double high, String color) : super('x', color) {
		aa = new Anchor(this, x, y);
		ch = new HorizontalConstraint(this, x, y, wide);
		cv = new VerticalConstraint(this, x, y, high);

		updateEquation();
	}

	List<ControlPoint> get anchors => [aa, cv, ch];
	
	double eval(double x) {
		return aa.y;
	}
	
	bool render() {
		c2d.beginPath();
		c2d.ellipse(graph.pttopx_x(h), graph.pttopx_y(k), wide.abs() * graph.xscl, high.abs() * graph.yscl, 0.0, 0.0, 2*PI, false);
		c2d.closePath();
		c2d.stroke();
		return true;
	}

	void renderControls() {
		cv.render();
		ch.render();
		aa.render();
	}

	void mouseMoved(double x, double y) {
		aa.mouseMoved(x, y);
		ch.mouseMoved(x, y);
		cv.mouseMoved(x, y);
	}
	
	bool mouseDragged(double x, double y) {
		return aa.mouseDragged(x, y) || ch.mouseDragged(x, y) || cv.mouseDragged(x, y);
	}
	
	void updateEquation() {
		h = round(aa.x, roundFactor);
		k = round(aa.y, roundFactor);
		
		ch.set(h, k);
		cv.set(h, k);
		
		wide = round(ch.wide, roundFactor);
		high = round(cv.high, roundFactor);
		
		from = h - a/2;
		to = h + a/2;
	}

	String generateEquation() {
		//return '((x - 5)^2 / 3^2) + ((y - 3)^2 / 3^2) = 1'
		double aa = round(a, postRoundFactor);
		double bb = round(b, postRoundFactor);
		double hh = round(h, postRoundFactor);
		double kk = round(k, postRoundFactor);

		return '((x - $hh)^2 / $aa^2) + ((y - $kk)^2 / $bb^2) = 1';
	}

	bool serializeGrf(Config grf, Map<String, int> ids) {
		int i = ids['relations'];
		String section = 'Relation$i'; 
		grf.add_section(section);
		grf.set(section, 'Relation', generateEquation());
		grf.set(section, 'Style', '5');
		grf.set(section, 'LineStyle', '0');
		grf.set(section, 'Size', '$size');
		int bgr = rgbStringToBgr(color);
		grf.set(section, 'Color', '0x${bgr.toRadixString(16)}');
		grf.set(section, 'Alpha', '100');
		ids['relations']++;
		return true;
	}

	Object serialize() {
		return [
			'ellipse',
			[aa.serialize(), cv.serialize(), ch.serialize()],
			size,
			color
		];
	}
	
	List<FunctionContainer> get functions => [this];
}

class CircleGeom extends EllipseGeom {
	Anchor ab = new Anchor(null, 0.0, 0.0);
	
	List<ControlPoint> get anchors => [super.anchors, ab].expand((i) => i).toList();
	
	double radius;
	
	CircleGeom.deserialize(List data) : super(0.0, 0.0, 0.0, 0.0, '') {
		aa = new Anchor.deserialize(this, data[1][0]);
		ab = new Anchor.deserialize(this, data[1][1]);
		size = data[2];
		color = data[3];
	}
	
	CircleGeom(double x, double y, double r, String color) : super(x, y, r, r, color) {
		ab.set(x, y);
	}
	
	void updateEquation() {
		h = round(aa.x, roundFactor);
		k = round(aa.y, roundFactor);
		radius = round(sqrt(pow(ab.x - h, 2) + pow(ab.y - k, 2)), roundFactor); // distance equation to figure out the radius :-)
		wide = radius;
		high = radius;
	}
	
	bool render() {
		return super.render();
	}
	
	void renderControls() {
		aa.render();
		ab.render();
	}
	
	void mouseMoved(double x, double y) {
		aa.mouseMoved(x, y);
		ab.mouseMoved(x, y);
	}

	bool mouseDragged(double x, double y) {
		return aa.mouseDragged(x, y) || ab.mouseDragged(x, y);
	}
	
	Object serialize() {
		return [
			'circle',
			[aa.serialize(), ab.serialize()],
			size,
			color
		];
	}
	
	String generateEquation() {
		double rr = round(radius, postRoundFactor);
		double hh = round(h, postRoundFactor);
		double kk = round(k, postRoundFactor);

		return '(x - $hh)^2 + (y - $kk)^2 = $rr^2';
	}
}

// class CircleGeom extends EllipseGeom {
// 	CircleGeom(float radius 
// }

class AffineFunction extends Function {
	Anchor aa, ab;

	List<ControlPoint> get anchors => [aa, ab];
	
	double a, b;

	void updateA() {
		a = round((ab.y - aa.y) / (ab.x - aa.x), roundFactor);
	}

	void updateB() {
		b = round((ab.y - ab.x*a), roundFactor);
	}

	AffineFunction.deserialize(List data) : super.generic() {
		from = data[1];
		to = data[2];
		aa = new Anchor.deserialize(this, data[3][0]);
		ab = new Anchor.deserialize(this, data[3][1]);
		size = data[4] is List ? 3.0 : data[4] * 1.0;
		color = data[5] is int ? '#000000' : data[5];
	}
	
	AffineFunction(String color, [double a = null, double b = null]) : super('x', color) {
		aa = new Anchor(this, 0.0, 0.0);
		ab = new Anchor(this, 5.0, 5.0);

		updateEquation();

		if (a != null) this.a = a;
		if (b != null) this.b = b;
	}

	double eval(num x) {
		return a * x + b;
	}

	List<double> xeval(double y) {
		return [(y - b) / a];
	}
	
	bool render() {
		return false;
	}

	void renderControls() {
		aa.render();
		ab.render();
	}

	void mouseMoved(double x, double y) {
		aa.mouseMoved(x, y);
		ab.mouseMoved(x, y);
	}

	bool mouseDragged(double x, double y) {
		return aa.mouseDragged(x, y) || ab.mouseDragged(x, y);
	}

	void updateEquation() {
		updateA();
		updateB();
		from = min(aa.x, ab.x);
		to = max(aa.x, ab.x);

		super.updateEquation();
	}
	
	void setIntersection(AffineFunction old) {
		double res = (old.b - b) / (a - old.a);
		
//		print(generateEquation());
//		print(old.generateEquation());
//		print(res);
		
		if (old.ab.x < old.aa.x) {
			if (ab.x > old.ab.x) {
				old.from = res;
				from = res;
				print('a');
			} else {
				old.from = res;
				to = res;
				print('b');
			}
		} else {
			if (ab.x > old.ab.x) {
				old.to = res;
				from = res;
				print('c');
			} else {
				old.to = res;
				to = res;
				print('d');
			}
		}
	}
	
	Object serialize() {
		return [
			'affine',
			from,
			to,
			[aa.serialize(), ab.serialize()],
			size,
			color
		];
	}

	String generateEquation() {
		bool da = a % 1 == 0;
		bool db = b % 1 == 0;

		var aa = round(a, postRoundFactor);
		var bb = round(b, postRoundFactor);

		// increases fidelity by a little bit
		// if (aa < a) bb += 0.02;
		// else if (aa > a) bb -= 0.02;
		
		bb = round(bb, postRoundFactor);

		if (da) aa ~/= 1;
		if (db) bb ~/= 1;

		String _a = (a == 0.0 || a == 1.0) ? "" : "${aa}";
		var _b = bb.abs();

		String token = b > 0 ? "+" : b < 0 ? "-" : "";

		if (a == 0.0) return "$bb";
		else { 
			if (b == 0.0) return '${_a}x';
			return '${_a}x $token $_b';
		}
	}
}

class QuadraticFunction extends Function {
	Anchor aa, ab, ac;
	
	List<ControlPoint> get anchors => [aa, ab, ac];

	double a, b, c;

	QuadraticFunction.deserialize(List data) : super.generic() {
		from = data[1];
		to = data[2];
		aa = new Anchor.deserialize(this, data[3][0]);
		ab = new Anchor.deserialize(this, data[3][1]);
		ac = new Anchor.deserialize(this, data[3][2]);
		size = data[4];
		color = data[5];
	}
	
	QuadraticFunction(String color, [double a = 1.0, double b = 0.0]) : super('x', color) {
		aa = new Anchor(this, 0.0, 0.0);
		ab = new Anchor(this, 3.0, 1.5);
		ac = new Anchor(this, 5.0, 5.0);

		updateEquation();
	}

	QuadraticFunction.reciprocal(String color, SquareRootFunction a) : super('x', color) {
		setReciprocal(a);

		updateEquation();
	}
	
	void setReciprocal(SquareRootFunction a) {
		aa = new Anchor(this, a.aa.x, a.aa.y);
		ac = new Anchor(this, a.ab.x, a.ab.y);
		ab = new Anchor(this, (aa.x - ac.x) * 0.6, (aa.y - ac.y) * (1/3+3));
	}

	double eval(num x) {
		if (a == null || b == null || c == null)
			return null;
		
		return a*pow(x, 2) + b*x + c;
	}
	
	List<double> xeval(double y) {
		double sqp=  sqrt(pow(b, 2) + 4*a*(y - c));
		
		return [(b + sqp) / (-2 * a), (b - sqp) / (-2 * a)];
	}

	bool render() {
		return false;
	}

	void renderControls() {
		aa.render();
		ab.render();
		ac.render();
	}

	void mouseMoved(double x, double y) {
		aa.mouseMoved(x, y);
		ab.mouseMoved(x, y);
		ac.mouseMoved(x, y);
	}

	bool mouseDragged(double x, double y) {
		return aa.mouseDragged(x, y) || ab.mouseDragged(x, y) || ac.mouseDragged(x, y);
	}

	void updateEquation() {
		Anchor amin, acen, amax;
		if (aa.x < ab.x && aa.x < ac.x) amin = aa;
		else if (ab.x < aa.x && ab.x < ac.x) amin = ab;
		else if (ac.x < aa.x && ac.x < ab.x) amin = ac;

		if (aa.x > ab.x && aa.x > ac.x) amax = aa;
		else if (ab.x > aa.x && ab.x > ac.x) amax = ab;
		else if (ac.x > aa.x && ac.x > ab.x) amax = ac;

		if (aa != amin && aa != amax) acen = aa;
		if (ab != amin && ab != amax) acen = ab;
		if (ac != amin && ac != amax) acen = ac;
		
		if (amin == null || acen == null || amax == null)
			return;
		
		Matrix3 coef = new Matrix3(
			amin.x*amin.x, amin.x, 1.0,
			acen.x*acen.x, acen.x, 1.0,
			amax.x*amax.x, amax.x, 1.0
		);

		Matrix3 cons = new Matrix3(
			amin.y, amin.y, amin.y,
			acen.y, acen.y, acen.y,
			amax.y, amax.y, amax.y
		);

		coef.invert();
		Matrix3 prod = cons * coef;
		a = round(prod[0], roundFactor);
		b = round(prod[3], roundFactor);
		c = round(prod[6], roundFactor);

		from = round(amin.x, roundFactor);
		to = round(amax.x, roundFactor);

		super.updateEquation();
	}
	
	Object serialize() {
		return [
			'quadratic',
			from,
			to,
			[aa.serialize(), ab.serialize(), ac.serialize()],
			size,
			color
		];
	}

	String generateEquation() {
		double h = -b / (2 * a);
		double k = (4*a*c - b*b) / (4*a);

		var aa = round(a, postRoundFactor);
		var hh = round(h, postRoundFactor);
		var kk = round(k, postRoundFactor);

		return "${aa}(x - $hh)^2 + $kk";
		// return '$a*x^2 + $b*x + $c';
	}
}

class SquareRootFunction extends Function {
	Anchor aa, ab;
	
	List<ControlPoint> get anchors => [aa, ab];

	double a, h, k;
	double b = 1.0;

	void updateA() {
		if (ab.x >= aa.x)
			a = round((ab.y - k) / sqrt(ab.x - h), roundFactor); // found using cymath
		else
			a = round((ab.y - k) / sqrt(h - ab.x), roundFactor);
		
		if (ab.x > aa.x) b = 1.0;
		else b = -1.0;
	}

	void updateH() {
		h = round(aa.x, roundFactor);
	}

	void updateK() {
		k = round(aa.y, roundFactor);
	}

	SquareRootFunction.deserialize(List data) : super.generic() { 
		from = data[1];
		to = data[2];
		aa = new Anchor.deserialize(this, data[3][0]);
		ab = new Anchor.deserialize(this, data[3][1]);
		size = data[4] * 1.0;
		color = data[5];
	}
	
	SquareRootFunction(String color, [double a = 1.0, double b = 0.0]) : super('x', color) {
		aa = new Anchor(this, 0.0, 0.0);
		ab = new Anchor(this, -5.0, 5.0);

		updateEquation();
	}

	// SquareRootFunction.passing(List<double> points, String color) : super('x', color) {
	// 	aa = new Anchor(this, 0.0, 0.0);
	// 	ab = new Anchor(this, 5.0, 5.0);
	// }

	double eval(num x) {
		return a * sqrt(b*x - b*h) + k;
	}

	List<double> xeval(num y) {
		return [(pow((y - k), 2) / (b * pow(a, 2))) + h];
	}
	
	bool render() {
		return false;
	}

	void renderControls() {
		aa.render();
		ab.render();
	}

	void mouseMoved(double x, double y) {
		aa.mouseMoved(x, y);
		ab.mouseMoved(x, y);
	}

	bool mouseDragged(double x, double y) {
		return aa.mouseDragged(x, y) || ab.mouseDragged(x, y);
	}

	void updateEquation() {
		from = min(aa.x, ab.x);
		to = max(aa.x, ab.x);
		
//		if (b > 0.0) from = null;
//		else if (b < 0.0) to = null;
		
		updateH();
		updateK();
		updateA();

		super.updateEquation();
	}
	
	Object serialize() {
		return [
			'sqrt',
			from,
			to,
			[aa.serialize(), ab.serialize()],
			size,
			color
		];
	}

	String generateEquation() {
		//a * sqrt(b*x - b*h) + k
		var aa = round(a, min(3, postRoundFactor));
		var hh = round(h, min(2, postRoundFactor));
		var kk = round(k, min(2, postRoundFactor));
	
		String pp = '';
		String sym1 = b > 0.0 ? (hh > 0.0 ? '-' : '+') : (hh > 0.0 ? '+' : '-');
		String sym2 = kk > 0.0 ? '+' : '-';
		
		double hhh = hh.abs();
		double kkk = kk.abs(); // KU KLUX KLAN
		
		if (b > 0.0) pp = 'x $sym1 $hhh';
		else pp = '-x $sym1 $hhh';
		
		if (!Settings.noSqrt) return '${aa}sqrt($pp) $sym2 $kkk';
		else return '${aa}($pp)^(1/2) $sym2 $kkk';
	}
}

abstract class ControlPoint {
	Function function;
	Vector2 point;
	
	double get x => point.x;
	double get y => point.y;
	double get px => graph.pttopx_x(x);
	double get py => graph.pttopx_y(y);
	
	double size = 6.0;

	void set x(double v) {
		point.x = v;
	}

	void set y(double v) {
		point.y = v;
	}
	
	void set(double x, double y) {
		point.setValues(x, y);
	}
	
	ControlPoint(this.function);
	
	bool isHovering(num x, num y, num mx, num my) {
		double px = graph.pttopx_x(x);
		double py = graph.pttopx_y(y);
		double mpx = graph.pttopx_x(mx);
		double mpy = graph.pttopx_y(my);

		double dist = sqrt(pow(mpx - px, 2) + pow(mpy - py, 2));

		return dist < size;
	}
	
	void mouseMoved(double mx, double my) {
	}

	bool mouseDragged(double mx, double my) {
		return false;
	}

	void render() {
	}
	
	// reusability at its finest
	void renderAnchor(num x, num y, bool hovering) {
		c2d.fillStyle = 'black';
        		
		double nsize = size;
		if (hovering) 
			nsize *= 2;
		
		double xx = -((graph.xmin - x) / graph.xrange) * SCREEN_W;
		double yy = -((graph.ymin - y) / graph.yrange) * SCREEN_H;
		yy = -yy;
		
		yy += SCREEN_H;
//		c2d.drawImageScaled(graph.backgroundImage, xx, yy - backgroundImage.height / yf, backgroundImage.width / xf, backgroundImage.height / yf);
//		print('point=[${xx}, ${yy}]');
		
		c2d.fillRect(xx - nsize/2, yy - nsize / 2, nsize, nsize);
	}
}

class Anchor extends ControlPoint {
	bool hovering = false;
	List<Anchor> tangents = [];
	Anchor snapper = null;

	Anchor.deserialize(Function func, data) : super(func) {
		point = new Vector2(data[0], data[1]);
	}
	
	Anchor.zero(Function func) : this(func, 0.0, 0.0);
	
	Anchor(Function func, double x, double y) : super(func) {
		point = new Vector2(x, y);
	}

	double dist(double x1, double y1, double x2, double y2) {
		return sqrt(pow(x2 - x1, 2) + pow(y2 - y1, 2));
	}
	
	void mouseMoved(double mx, double my) {
		bool now = isHovering(x, y, mx, my);
		
		if (hovering != now) {
			hovering = now;
			graph.render();
		}
	}

	bool mouseDragged(double mx, double my) {
		if (hovering) {
			bool snaps = false;
			List<Anchor> newTangents = [];
			Anchor sourceTangent = null;

			tools.selection.selected.forEach((Function e) => e.anchors.where((c) => c is Anchor).forEach((c) {
				if (c == this)
					return;
				
				if (!snaps && dist(Mouse.x * 1.0, Mouse.y * 1.0, c.px, c.py) < 10) {
					snaps = true;
					
					x = c.x;
					y = c.y;
					
					snapper = c;
					
//					sourceTangent = c;
					return;
				}
			}));
			
			if (!snaps) {
				x += mx;
				y += my;
				snapper = null;
//				tangents.forEach((a) => a.tangents.remove(this));
//				tangents.clear();
			} else {
//				if (sourceTangent != null) {
//					List<Anchor> stack = [];
//					List<Anchor> processed = [];
//					stack.add(sourceTangent);
//					
//					processed.add(sourceTangent);
//					processed.add(this);
//
//					while (stack.length > 0) {
//						Anchor current = stack.removeAt(0);
//						
//						current.tangents.forEach((a) {
//							if (!processed.contains(a)) {
//								stack.add(a);
//							}
//						});
//						
//						processed.add(current);
//					}
//					
//					processed.forEach((a) {
//						a.tangents.clear();
//						a.tangents.addAll(processed);
//						a.tangents.remove(a);
//					});
//					
//					tangents.forEach((a) {
//						a.function.color = '#0000ff';
//					});
//					function.color = '#0000ff';
//				}
			}
			
			if (function != null)
				function.updateEquation();
	
			graph.render();
			return true;
		}

		return false;
	}

	void render() {
		renderAnchor(x, y, hovering);
	}
	
	Object serialize() {
		return [
			x,
			y
		];
	}
}

class VerticalConstraint extends ControlPoint {
	double high = 0.0;
	List<bool> hovers = [false, false];

	VerticalConstraint.deserialize(Function function, List data) : super(function) {
		point = new Vector2(data[0], data[1]);
    	high = data[2];
    	this.function = function;
	}
	
	VerticalConstraint(Function function, double x, double y, this.high) : super(function) {
		this.point = new Vector2(x, y);
	}

	void mouseMoved(double mx, double my) {
		bool now0 = isHovering(x, y - high, mx, my);
		bool now1 = isHovering(x, y + high, mx, my);
        		
		if (hovers[0] != now0) {
			hovers[0] = now0;
			graph.render();
		}
		
		if (hovers[1] != now1) {
			hovers[1] = now1;
			graph.render();
		}
	}

	bool mouseDragged(double dx, double dy) {
		if (hovers[0] || hovers[1]) {
			high += hovers[0] ? -dy : dy;
	
			graph.render();
			function.updateEquation();
			return true;
		}
		
		return false;
	}
	
	void render() {
		c2d.setLineDash([]);
		c2d.strokeStyle = '#9a9a9a';
		c2d.beginPath();
		c2d.moveTo(graph.pttopx_x(x), graph.pttopx_y(y - high));
		c2d.lineTo(graph.pttopx_x(x), graph.pttopx_y(y + high));
		c2d.closePath();
		c2d.stroke();
		c2d.setLineDash([]);
		
		renderAnchor(x, y - high, hovers[0]);
		renderAnchor(x, y + high, hovers[1]);
	}
	
	Object serialize() {
		return [
			point.x,
			point.y,
			high
		];
	}
}

class HorizontalConstraint extends ControlPoint {
	double wide = 0.0;
	List<bool> hovers = [false, false];

	HorizontalConstraint.deserialize(Function function, List data) : super(function) {
		point = new Vector2(data[0], data[1]);
    	wide = data[2];
	}
	
	HorizontalConstraint(Function function, double x, double y, this.wide) : super(function) {
		this.point = new Vector2(x, y);
	}
	
	void render() {
		c2d.setLineDash([]);
		c2d.strokeStyle = '#9a9a9a';
		c2d.beginPath();
		c2d.moveTo(graph.pttopx_x(x - wide), graph.pttopx_y(y));
		c2d.lineTo(graph.pttopx_x(x + wide), graph.pttopx_y(y));
		c2d.closePath();
		c2d.stroke();
		c2d.setLineDash([]);
		
		renderAnchor(x - wide, y, hovers[0]);
		renderAnchor(x + wide, y, hovers[1]);
	}
	
	void mouseMoved(double mx, double my) {
		bool now0 = isHovering(x - wide, y, mx, my);
		bool now1 = isHovering(x + wide, y, mx, my);
        		
		if (hovers[0] != now0) {
			hovers[0] = now0;
			graph.render();
		}
		
		if (hovers[1] != now1) {
			hovers[1] = now1;
			graph.render();
		}
	}

	bool mouseDragged(double dx, double dy) {
		if (hovers[0] || hovers[1]) {
			wide += hovers[0] ? -dx : dx;
	
			graph.render();
			function.updateEquation();
			return true;
		}
		
		return false;
	}
	
	Object serialize() {
		return [
			point.x,
			point.y,
			wide
		];
	}
}

