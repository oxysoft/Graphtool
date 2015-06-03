part of graph;

class Selection {
	Vector2 p1, p2;
	
	Selection() {
		p1 = new Vector2.zero();
		p2 = new Vector2.zero();
	}
	
	void start(double x, double y) {
		p1.x = x;
		p1.y = y;
		
		end(x, y);
	}
	
	void end(double x, double y) {
		p2.x = x;
		p2.y = y;
	}
	
	double get startx => min(p1.x, p2.x);
	
	double get starty => min(p1.y, p2.y);
	
	double get endx => max(p1.x, p2.x);
	
	double get endy => max(p1.y, p2.y);
	
	double get w => endx - startx;
	
	double get h => endy - starty;
	
	void render() {
	}
}

void roundRect(double x, double y, double w, double h, [double r = 5.0, bool stroke = true, bool fill = false]) {
	double r2d = PI/180;
	c2d.beginPath();
    c2d.moveTo(x + r, y);
    c2d.lineTo(x + w - r, y);
    c2d.arc(x + w - r, y + r, r, r2d*270, r2d*360, false);
    c2d.lineTo(x + w, y + h - r);
    c2d.arc(x + w - r, y + h - r, r, r2d*0, r2d*90, false);
    c2d.lineTo(x + r, y + h);
    c2d.arc(x + r, y + h - r, r, r2d*90, r2d*180, false);
    c2d.lineTo(x, y + r);
    c2d.arc(x + r, y + r, r, r2d*180, r2d*270, false);
	c2d.closePath();
	
	if (stroke) c2d.stroke();
	if (fill) c2d.fill();
}

bool between(num v, num b1, num b2) {
	return v >= min(b1, b2) && v <= max(b1, b2);
}

bool betweenr(num v, num b1, num b2) {
	return v >= b1 || v <= b2;
}

bool pointInside(double px, double py, double rx, double ry, double rw, double rh) {
	print([[px >= rx, px <= rx + rw, py >= ry - rh, py <= ry], [px, py, rx, ry, rw, rh]]);
	return px >= rx && px <= rx + rw && py >= ry - rh && py <= ry;
}