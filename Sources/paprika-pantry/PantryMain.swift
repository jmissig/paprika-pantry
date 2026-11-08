import ArgumentParser
import PantryKit

@main
struct PantryMain {
    static func main() async {
        await PantryCLI.main()
    }
}
