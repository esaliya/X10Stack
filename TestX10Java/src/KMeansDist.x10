/*
 *  This file is part of the X10 project (http://x10-lang.org).
 *
 *  This file is licensed to You under the Eclipse Public License (EPL);
 *  You may not use this file except in compliance with the License.
 *  You may obtain a copy of the License at
 *      http://www.opensource.org/licenses/eclipse-1.0.php
 *
 *  (C) Copyright IBM Corporation 2006-2010.
 */

import x10.io.Console;
import x10.util.Random;

public class KMeansDist {

    static val DIM=2;
    static val CLUSTERS=4;
    static val POINTS=2000;
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
        
        // creates a distributed array to represent data points
        val points = DistArray.make[Float](points_dist, (p:Point)=>rnd().nextFloat());

        // global cluster centers 
        val central_clusters = new Array[Float](CLUSTERS*DIM, (i:int) => {
        	// take the first four points as initial centers
        	val p = Point.make([i/DIM, i%DIM]);
            return at (points_dist(p)) points(p);
        });
        
        //  global count of points assigned to each cluster center
        val central_cluster_counts = new Array[Int](CLUSTERS);

        // keeps the previous set of centers during iterations (global)
		val old_central_clusters = new Array[Float](CLUSTERS*DIM);

		

		/* refine cluster centers */
        for (i in 1..ITERATIONS) {

            Console.OUT.println("Iteration: "+i);

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
                	Console.OUT.println("there id: " + there.id + " here id:" + here.id);
                	
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
        for (var d:Int=0 ; d<DIM ; ++d) { 
            for (var k:Int=0 ; k<CLUSTERS ; ++k) { 
                if (k>0)
                    Console.OUT.print(" ");
                Console.OUT.print(central_clusters(k*DIM+d));
            }
            Console.OUT.println();
        }
    }
}

// vim: shiftwidth=4:tabstop=4:expandtab
