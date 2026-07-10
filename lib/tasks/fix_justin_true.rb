s = Survivor.find(180)
s.bio = %Q(Justin True is a 6'4" former MMA fighter ("<a href="https://www.tapology.com/fightcenter/fighters/43292-justin-true" target="_blank" rel="noopener noreferrer">The Boogeyman</a>") from Oregon who debuted on <a href="/episodes/182">Naked and Afraid S18E7 "Enter the Queen"</a> (Mexico, 2025). In a mentor-format episode he was guided by franchise legend Laura Zerra alongside fellow mentee Malik Nyasha. More information is available on his <a href="https://www.justintrueofficial.com/" target="_blank" rel="noopener noreferrer">official site</a>.)
s.save!
puts "OK: #{s.bio[0, 100]}..."
