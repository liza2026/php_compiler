<?php // OK: интерфейсы, implements нескольких, abstract/final
interface Speaks {}
interface Moves {}
abstract class Base {}
final class Robot extends Base implements Speaks, Moves {
}
