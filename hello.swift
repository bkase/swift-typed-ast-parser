func smart(accountA: Int, accountB: Int, amt: Int) -> (accountA: Int, accountB: Int) {
  guard (amt <= 50) else {
    return (accountA, accountB)
  }
  /*
  guard (accountA <= amt) else {
  }
  */
  return (accountA - amt, accountB + amt)
}
