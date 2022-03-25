require 'webdrivers'
require './words.rb'
require 'byebug'

class WordleSolver
  
  attr_reader :driver

  def initialize
    options = Selenium::WebDriver::Options.chrome
    @driver = Selenium::WebDriver.for :chrome, options: options
    @driver.manage.timeouts.implicit_wait = 10
    @driver.get 'https://www.nytimes.com/games/wordle/index.html'
    @game_div = driver.find_element(css: 'game-app').shadow_root.find_element(css: 'div#game')
    @words = PossibleWords::WORDS 
    @word = ['', '', '', '', '']
    @present = {}
    @absent = []
    @current_row = 1
  end

  def solve
    close_modal
    next_guess = 'store'
    6.times do 
      guess(next_guess)
      sleep(3)
      get_feedback(next_guess)
      break if game_won?
      next_guess = formulate_guess
    end
  end

  def game_won?
    @word.each { |letter| return false if letter == '' }
    true
  end

  def close_modal
    @game_div.find_element(css: 'game-modal').shadow_root.find_element(css: 'div.close-icon').click
  end

  def guess(word)
    @driver.action.send_keys(word).send_keys(:enter).perform
  end

  def formulate_guess
    @words.each do |word|
      return word if valid_guess?(word)
    end
    'guess'
  end

  def valid_guess?(word)
    includes_correctly_positioned_letters?(word) &&
    includes_present_letters_in_positions_not_tried?(word) &&
    does_not_include_absent_letters?(word)
  end

  def includes_correctly_positioned_letters?(word)
    @word.each_with_index do |letter, index|
      if letter != ''
        return false if word[index] != letter
      end
    end
  end

  def includes_present_letters_in_positions_not_tried?(word)
    @present.each do |letter, subhash|
      return false if !word.include?(letter)
      subhash[:positions_tried].each do |position|
        return false if word[position] == letter
      end
    end
  end

  def includes_correct_letter_count(word)
    @present.each do |letter, subhash|
      if (subhash[:min_count] && word.count(letter) < subhash[:min_count]) ||
         (subhash[:max_count] && word.count(letter) > subhash[:max_count])
        return false
      end
    end
  end

  def does_not_include_absent_letters?(word)
    @absent.each do |letter|
      return false if word.include?(letter)
    end
  end

  def get_feedback(word)
    row = @game_div.find_element(css: "game-row:nth-of-type(#{@current_row})").shadow_root
    feedback_hash = create_feedback_hash(word)

    1.upto(5) do |n|
      tile = row.find_element(css: "game-tile:nth-of-type(#{n})")
      letter = tile.attribute("letter")
      evaluation = tile.attribute("evaluation")
      position = n - 1
      feedback_hash[letter][evaluation].push(position)
    end
    
    add_feedback(feedback_hash)
    @current_row += 1
  end

  def create_feedback_hash(word)
    feedback_hash = {}

    word.each_char do |char|
      if !feedback_hash[char]
        feedback_hash[char] = {
          'absent' => [],
          'present' => [],
          'correct' => []
        }
      end
    end
    feedback_hash
  end

  def add_feedback(feedback_hash)
    feedback_hash.each do |char, feedback|
      if !@present[char] && (feedback['present'].length > 0 || feedback['correct'].length > 0)
        @present[char] = { positions_tried: [] }
      end
      
      feedback['correct'].each do |position|
        @word[position] = char
      end

      feedback['present'].each do |position|
        @present[char][:positions_tried].push(position)
      end

      if feedback['absent'].length == 0
        min_count = feedback['present'].length + feedback['correct'].length
        @present[char][:min_count] = min_count 
      else
        if (feedback['present'].length > 0) || (feedback['correct'].length > 0)
          max_count = feedback['present'].length + feedback['correct'].length
          @present[char][:max_count] = max_count
        else
          @absent.push(char)
        end
      end
    end
  end
end

begin
  solver = WordleSolver.new
  solver.solve
  sleep(5)
ensure
  solver.driver.quit
end
  
