part of graph;

class Model {
	Graph graph;
	List<Vector3> vertices = [];
	List<int> indices = [];
	
	Model(this.graph);
	
    double clamp(double v, [double mi = 0.0, double ma = 1.0]) {
    	return max(mi, min(v, ma));
    }

    double interpolate(double min, double max, double gradient) {
    	return min + (max - min) * clamp(gradient);
    }

    void drawTriangle(Vector3 p1, Vector3 p2, Vector3 p3) {
    	graph.plotLine(p1.x, p1.y, p2.x, p2.y, '#000000');
		graph.plotLine(p1.x, p1.y, p3.x, p3.y, '#000000');
		graph.plotLine(p2.x, p2.y, p3.x, p3.y, '#000000');
    }

    void load(String url) {
    	HttpRequest.getString(url).then((String data) {
            // parses basic obj format

    		List<String> lines = data.split('\n');
    		
    		List<double> vertexBuffer = [];
    		
    		lines.forEach((line) {
    			if (line.startsWith('v ')) {
    				line = line.substring(2);
    				var nums = line.split(' ');
    				nums.forEach((datum) {
    					if (datum.isNotEmpty)
   	 						vertexBuffer.add(double.parse(datum));
    				});
    			}
    			
    			if (line.startsWith('f ')) {
    				line = line.substring(2);
    				var groups = line.split(' ');
    				for (int i = 0; i < groups.length; i++) {
    					String gr = groups[i];
    					if (gr.isNotEmpty) {
							var split = gr.split('/');
							for (int j = 0; j < split.length; j++) {
								if (isNumeric(split[j])) {
									if (j % 3 == 0)
										indices.add(int.parse(split[j]) - 1);
								}
							}
    					}
    				}
    			}
    		});
    		
    		for (int i = 0; i < vertexBuffer.length; i += 3)
    			vertices.add(new Vector3(vertexBuffer[i], vertexBuffer[i + 1], vertexBuffer[i + 2]));
    		
    		print('vertexCount: ${vertices.length}');
    		
    		render();
    		
    		print('functionCount: ${graph.functions.len}');
    		
//    		new Timer.periodic(const Duration(milliseconds: 1~/60), (e) {
//				render();
//				iter++;
//			});
   		});
    }
    
    int iter = 0;
    
    List<Vector3> getFace(int i) {
    	if (i > indices.length + 1)
    		return [];
    	
    	return [
			vertices[indices[i]],
			vertices[indices[i + 1]],
			vertices[indices[i + 2]],
    	];
    }
    
    var perspective = makePerspectiveMatrix(75 * PI/180, element.height / element.width, 0.0001, 1000000);
    
    void render() {
    	graph.functions.list.clear();
		Matrix4 transform = new Matrix4.identity();
		
		transform.translate(2.0, 2.0);
		
		transform.translate(0.5, 0.5);
		transform.rotateY(iter*0.05 * PI/180);
		transform.rotateX(15 * PI/180);
		transform.translate(-0.5, -0.5);
		
		transform.scale(1.5, 1.5);
		
		transform *= perspective;
		
		for (int i = 0; i < indices.length - 3; i += 3) {
			var face = getFace(i);
			
			Vector3 pixelA = transform * face[0];
			Vector3 pixelB = transform * face[1];
			Vector3 pixelC = transform * face[2];
			
//			var color = 0.25 + (faceIndex % (indices.length ~/ 3)) * 0.75 / (indices.length ~/ 3);
//			color = (color * 255.0).round().toRadixString(16);
			
			drawTriangle(pixelA, pixelB, pixelC);
		}
		
		int i = vertices.length - 3;
//		var p1 = transform * new Vector3(vertices[i], vertices[i + 1], vertices[i + 2]);
//		var p2 = transform * new Vector3(vertices[0], vertices[1], vertices[2]);
		
//		graph.plotLine(p1.x, p1.y, p2.x, p2.y, '#000000');
		graph.render();
    }
}

