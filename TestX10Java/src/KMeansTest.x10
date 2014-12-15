import x10.io.Console;
import x10.util.Random;
public class KMeansTest {
	static val DIM=3;
	static val CLUSTERS=4;
	static val POINTS=20;
	static val ITERATIONS=50;

	static val points_region = 0..(POINTS-1)*0..(DIM-1);

	public static def main (Array[String]) {
		// random generator local to each place 
		val rnd = PlaceLocalHandle.make[Random](PlaceGroup.WORLD, () => new Random(0));
		
		// local copy of current center points
		val local_curr_clusters = PlaceLocalHandle.make[Array[Float](1)](
				PlaceGroup.WORLD, () => new Array[Float](CLUSTERS*DIM));
		
		// sum of local points nearest to each center
		val local_new_clusters = PlaceLocalHandle.make[Array[Float](1)](
				PlaceGroup.WORLD, () =>  new Array[Float](CLUSTERS*DIM));
		
		// local count of points assigned to each center
		val local_cluster_counts = PlaceLocalHandle.make[Array[Int](1)](
				PlaceGroup.WORLD, ()=> new Array[Int](CLUSTERS));

		// domain decomposition by blocking along the zeroth dimension,
		// i.e. along 0..(POINTS-1)
		val points_dist = Dist.makeBlock(points_region, 0); 
		
		// initial points
		val initials = [ 0.687341f,0.29802f,0.752728f,
		0.419732f,0.37836f,0.0912831f,
		0.248889f,0.0659724f,0.416977f,
		0.711823f,0.0305533f,0.280535f,
		0.52954f,0.818765f,0.224503f,
		0.981434f,0.225217f,0.944875f,
		0.383762f,0.150229f,0.318658f,
		0.453673f,0.880605f,0.361181f,
		0.90988f,0.276158f,0.974794f,
		0.254215f,0.0159331f,0.792719f,
		0.796911f,0.24941f,0.759422f,
		0.513687f,0.243573f,0.625268f,
		0.857396f,0.811445f,0.20519f,
		0.539379f,0.386104f,0.446041f,
		0.778445f,0.611402f,0.438312f,
		0.333145f,0.0453983f,0.0177009f,
		0.105817f,0.00589306f,0.269783f,
		0.117595f,0.726253f,0.348978f,
		0.359102f,0.646129f,0.795696f,
		0.0122162f,0.309424f, 0.420688f
		];
		// creates a distributed array to represent data points
		val points = DistArray.make[Float](points_dist, ([i,j]:Point(2))=>initials(i*DIM+j));
		
		// print the initial points
		Console.OUT.println("initial points");
		for (var p:Int=0 ; p<POINTS ; ++p) { 
			for (var d:Int=0 ; d<DIM ; ++d) { 
				if (d>0)
					Console.OUT.print(" ");
				Console.OUT.print(points(p,d));
			}
			Console.OUT.println();
		}
		

		// global cluster centers 
		val central_clusters = new Array[Float](CLUSTERS*DIM, (i:int) => {
			// take the first four points as initial centers
			val p = Point.make([i/DIM, i%DIM]);
			return at (points_dist(p)) points(p);
		});
		
		// print the initial centers
		Console.OUT.println("initial centers");
		for (var k:Int=0 ; k<CLUSTERS ; ++k) { 
			for (var d:Int=0 ; d<DIM ; ++d) { 
				if (d>0)
					Console.OUT.print(" ");
				Console.OUT.print(central_clusters(k*DIM+d));
			}
			Console.OUT.println();
		}
		
		//  global count of points assigned to each cluster center
		val central_cluster_counts = new Array[Int](CLUSTERS);

		// keeps the previous set of centers during iterations (global)
		val old_central_clusters = new Array[Float](CLUSTERS*DIM);

		

		/* refine cluster centers */
		for (i in 1..ITERATIONS) {
			/* reset state */
			finish {
				// foreach place, d, where points are distributed do in a new task
				for (d in points_dist.places()) async at(d) {
					async {
						for (var j:Int=0 ; j<DIM*CLUSTERS ; ++j) {
							// copy the current centers to the local copy of current centers
							local_curr_clusters()(j) = central_clusters(j);
							// reset new centers to origin
							local_new_clusters()(j) = 0;
						}
					}
					async {
						for (var j:Int=0 ; j<CLUSTERS ; ++j) {
							// reset point count assigned to each center as zero 
							local_cluster_counts()(j) = 0;
						}
					}
				}
			}

			/* compute new clusters and counters */
			finish {
				// foreach point
				for (var p_:Int=0 ; p_<POINTS ; ++p_) {
					val p = p_;
					// do in a new task at the place of pth point
					async at(points_dist(p,0)) { 
						var closest:Int = -1;
						var closest_dist:Float = Float.MAX_VALUE;
						// foreach cluster center compute the Euclidean 
						// distance (square) from this point and assign
						// the point to the center with the closest distance
						for (var k:Int=0 ; k<CLUSTERS ; ++k) { 
							var dist : Float = 0;
							// sum of squared components (square of Euclidean distance)
							for (var d:Int=0 ; d<DIM ; ++d) { 
								val tmp = points(Point.make(p,d)) 
								- local_curr_clusters()(k*DIM+d);
								dist += tmp * tmp;
							}
							// closest check
							if (dist < closest_dist) {
								closest_dist = dist;
								closest = k;
							}
						}
						
						// it's possible for two activities in same place to compete for the 
						// increment operations below. So need to use atomic
						atomic { 
							// add point to the nearest center points group
							for (var d:Int=0 ; d<DIM ; ++d) { 
								local_new_clusters()(closest*DIM+d) += points(Point.make(p,d));
							}
							// increment the point count for the particular center
							local_cluster_counts()(closest)++;
						}
					}
				}
			}


			// copy gloabl centers to old global centers and clear global centers
			for (var j:Int=0 ; j<DIM*CLUSTERS ; ++j) {
				old_central_clusters(j) = central_clusters(j);
				central_clusters(j) = 0;
			}

			// clear global center point counts
			for (var j:Int=0 ; j<CLUSTERS ; ++j) {
				central_cluster_counts(j) = 0;
			}

			finish {
				// put global centers and center poin counts to X10 Global Ref 
				val central_clusters_gr = GlobalRef(central_clusters);
				val central_cluster_counts_gr = GlobalRef(central_cluster_counts);
				
				// the place where this code is executing
				val there = here;
				
				// foreach place, d, where points are distributed do in a new task at d
				for (d in points_dist.places()) async at (d) {
					
					// access PlaceLocalHandles 'here' and then data will be captured 
					// by 'at' and transfered to 'there' for accumulation
					val tmp_new_clusters = local_new_clusters();
					val tmp_cluster_counts = local_cluster_counts();
					
					
					// local points for each center and counts are transferred to 'there'
					// and the global ref arrays are updated
					at (there) atomic {
						for (var j:Int=0 ; j<DIM*CLUSTERS ; ++j) {
							central_clusters_gr()(j) += tmp_new_clusters(j);
						}
						for (var j:Int=0 ; j<CLUSTERS ; ++j) {
							central_cluster_counts_gr()(j) += tmp_cluster_counts(j);
						}
					}
				}
			}

			// by now  central_clusters should have received all the sums
			// of poins for each cluster
			for (var k:Int=0 ; k<CLUSTERS ; ++k) { 
				for (var d:Int=0 ; d<DIM ; ++d) {
					// take the mean of points for each cluster as the global centers
					central_clusters(k*DIM+d) /= central_cluster_counts(k);
				}
			}

			// test for convergence
			var b:Boolean = true;
			for (var j:Int=0 ; j<CLUSTERS*DIM ; ++j) { 
				if (Math.abs(old_central_clusters(j)-central_clusters(j))>0.0001) {
					b = false;
					break;
				}
			}
			if (b) break;

		}

		// print the new centers after convergence
		Console.OUT.println("final centers");
		for (var k:Int=0 ; k<CLUSTERS ; ++k) {
			for (var d:Int=0 ; d<DIM ; ++d) { 
				if (d>0)
					Console.OUT.print(" ");
				Console.OUT.print(central_clusters(k*DIM+d));
			}
			Console.OUT.println();
		}
	}
}