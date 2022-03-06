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
    guess('store')
    5.times do 
      get_feedback
      break if game_won?
      next_guess = formulate_guess
      guess(next_guess)
      sleep(3)
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
    @word.each_with_index do |letter, index|
      if letter != ''
        return false if word[index] != letter
      end
    end

    @absent.each do |letter|
      return false if word.include?(letter)
    end

    @present.each do |letter, incorrect_positions|
      return false if !word.include?(letter)
      incorrect_positions.each do |position|
        return false if word[position] == letter
      end
    end
  end

  def get_feedback
    row = @game_div.find_element(css: "game-row:nth-of-type(#{@current_row})").shadow_root
    1.upto(5) do |n|
      tile = row.find_element(css: "game-tile:nth-of-type(#{n})")
      letter = tile.attribute("letter")
      evaluation = tile.attribute("evaluation")
      add_feedback(letter, evaluation, n - 1)
    end
    
    @current_row += 1
  end

  def add_feedback(letter, evaluation, position)
    case evaluation
    when 'absent'
      @absent.push(letter)
    when 'present'
      if @present[letter]
        @present[letter].push(position)
      else
        @present[letter] = [position]
      end
    when 'correct'
      @present.delete(letter)
      @word[position] = letter if @word[position] == ''
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
  
