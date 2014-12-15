import x10.io.Console;
class AtomicTest {
  public static def main(Array[String]) {
    var rSum:Double = 0.0;
    /*finish {
      async for (int i=1 ; i<=n ; i+=2 ) {
        double r = 1.0d / i ; atomic rSum += r;
      }
      for (int j=2 ; j<=n ; j+=2 ) {
        double r = 1.0d / j ; atomic rSum += r;
      }
    }*/
    
    Console.OUT.println("rSum = " + rSum);
  }
}
