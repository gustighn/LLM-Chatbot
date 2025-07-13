import Nat "mo:base/Nat";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Iter "mo:base/Iter";

actor class Backend() {

  type PlayerProfile = {
    principal: Principal;
    name: Text;
    level: Nat;
    totalGames: Nat;
    totalWins: Nat;
    totalLosses: Nat;
  };

  type Question = {
    text: Text;
    answer: Int;
  };

  type Match = {
    id: Nat;
    player1: Principal;
    player2: Principal;
    questions: [Question];
    answers: [(Principal, [Bool])];
    finished: Bool;
  };

  var profiles: Buffer.Buffer<PlayerProfile> = Buffer.Buffer<PlayerProfile>(0);
  var waitingPlayer: ?Principal = null;
  var matches: Buffer.Buffer<Match> = Buffer.Buffer<Match>(0);
  var matchId: Nat = 0;

  // Helper: cari profil player
  func findProfile(p: Principal): ?PlayerProfile {
    for (i in Iter.range(0, profiles.size() - 1)) {
      let prof = profiles.get(i);
      if (prof.principal == p) return ?prof;
    };
    return null;
  };

  // Register/login player
  public shared({ caller }) func login(name: Text): async () {
    switch (findProfile(caller)) {
      case null {
        let profile: PlayerProfile = {
          principal = caller;
          name = name;
          level = 1;
          totalGames = 0;
          totalWins = 0;
          totalLosses = 0;
        };
        profiles.add(profile);
      };
      case _ {};
    };
  };

  // Matchmaking
  public shared({ caller }) func findMatch(): async ?Nat {
    switch (waitingPlayer) {
      case null {
        waitingPlayer := ?caller;
        return null;
      };
      case (?other) {
        if (other == caller) return null;
        let qs = generateQuestions(10);
        let m: Match = {
          id = matchId;
          player1 = other;
          player2 = caller;
          questions = qs;
          answers = [];
          finished = false;
        };
        matches.add(m);
        matchId += 1;
        waitingPlayer := null;
        return ?(matchId - 1);
      };
    };
  };

  // Generate math questions (dummy, not random)
  func generateQuestions(n: Nat): [Question] {
    Array.tabulate<Question>(n, func(i) {
      let a = i + 1;
      let b = (i + 3) % 10;
      {
        text = "Berapakah " # Nat.toText(a) # " + " # Nat.toText(b) # "?";
        answer = a + b;
      }
    })
  };

  // Submit answer
  public shared({ caller }) func submitAnswer(matchId: Nat, answers: [Int]): async () {
    let match = matches.get(matchId);
    let corrects = Array.tabulate<Bool>(answers.size(), func(i) {
      match.questions[i].answer == answers[i]
    });
    match.answers := match.answers # [(caller, corrects)];
    if (match.answers.size() == 2) {
      match.finished := true;
      updateProfiles(match);
    };
  };

  // Update profile setelah match selesai
  func updateProfiles(m: Match) {
    let (p1, a1) = m.answers[0];
    let (p2, a2) = m.answers[1];
    let score1 = Array.foldLeft<Bool, Nat>(a1, 0, func(acc, b) { if (b) acc + 1 else acc });
    let score2 = Array.foldLeft<Bool, Nat>(a2, 0, func(acc, b) { if (b) acc + 1 else acc });
    let prof1 = findProfile(p1);
    let prof2 = findProfile(p2);
    switch (prof1, prof2) {
      case (?pr1, ?pr2) {
        pr1.totalGames += 1;
        pr2.totalGames += 1;
        if (score1 > score2) {
          pr1.totalWins += 1;
          pr2.totalLosses += 1;
        } else if (score2 > score1) {
          pr2.totalWins += 1;
          pr1.totalLosses += 1;
        }
      };
      case _ {};
    };
  };

  // Get profile
  public query func getProfile(): async ?PlayerProfile {
    let caller = Principal.fromActor(this);
    findProfile(caller)
  };

  // Get match questions
  public query func getQuestions(matchId: Nat): async [Question] {
    matches.get(matchId).questions
  };

  // Get match result
  public query func getResult(matchId: Nat): async ?(Nat, Nat) {
    let m = matches.get(matchId);
    if (not m.finished) return null;
    let (p1, a1) = m.answers[0];
    let (p2, a2) = m.answers[1];
    let score1 = Array.foldLeft<Bool, Nat>(a1, 0, func(acc, b) { if (b) acc + 1 else acc });
    let score2 = Array.foldLeft<Bool, Nat>(a2, 0, func(acc, b) { if (b) acc + 1 else acc });
    ?(score1, score2)
  };
};