import x10.io.Console;
public class GlobalRefTest {
	public static def main(Array[String]):void {
		val cell = new Cell[Int](10);
		val cell_gr = GlobalRef(cell);
		
		at (here.next()){
			at (cell_gr){
				cell_gr()() = 11;
			}
		}
		
		Console.OUT.println("cell: " + cell());
		Console.OUT.println("cell_gr: " + cell_gr()());
		
		for (d in PlaceGroup.WORLD){
			Console.OUT.println("place id: " + here.id);
		}
	
	}
}