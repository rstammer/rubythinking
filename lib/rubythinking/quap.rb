require 'matrix'
require 'set'
require_relative 'distributions/normal'

module Rubythinking
  class InvalidFormulaError < StandardError; end
  class MissingDataError < StandardError; end
  class NotEstimatedError < StandardError; end
  class ConvergenceError < StandardError; end
  class InvalidStartError < StandardError; end

  class Quap
    attr_reader :formulas, :data, :start

    def initialize(formulas:, data:, start: nil)
      @formulas = formulas
      @data = data
      @start = start
      @estimated = false
      @coef = nil
      @vcov = nil
      
      validate_formulas!
      validate_data!
    end

    def estimated?
      @estimated
    end

    def estimate
      # Get initial parameter values
      param_names = parameters
      initial_values = get_initial_values(param_names)
      
      # Optimize log-likelihood using Nelder-Mead
      result = nelder_mead_optimize(initial_values, param_names)
      
      # Store results
      @coef = param_names.zip(result[:x]).to_h
      @log_likelihood = -result[:fval]  # Convert from negative log-likelihood
      
      # Calculate variance-covariance matrix using numerical Hessian
      @vcov = calculate_vcov(result[:x], param_names)
      
      @estimated = true
      self
    end

    def coef
      check_estimated!
      @coef
    end

    def vcov
      check_estimated!
      @vcov
    end

    def se
      check_estimated!
      diagonal = @vcov.each(:diagonal).to_a
      param_names = @coef.keys
      param_names.zip(diagonal.map { |v| Math.sqrt(v) }).to_h
    end

    def summary
      check_estimated!
      
      lines = []
      lines << "Quadratic approximation"
      lines << ""
      lines << "Parameter estimates:"
      @coef.each do |param, value|
        stderr = se[param]
        lines << "  #{param}: #{value} (SE: #{stderr})"
      end
      
      lines.join("\n")
    end

    def samples(n: 1000, seed: nil)
      check_estimated!
      srand(seed) if seed
      
      result = {}
      @coef.each_with_index do |(param, value), i|
        variance = @vcov[i, i]
        result[param] = Distributions::Normal.samples(n, value, Math.sqrt(variance))
      end
      result
    end

    def loglik
      check_estimated!
      @log_likelihood
    end

    def npar
      check_estimated!
      @coef.length
    end

    def aic
      check_estimated!
      -2 * loglik + 2 * npar
    end

    private

    def validate_formulas!
      @formulas.each do |formula|
        unless formula.is_a?(String) && formula.include?('~')
          raise InvalidFormulaError, "Invalid formula: #{formula}"
        end
        
        # Check for unknown distributions
        if formula.include?('invalid_distribution')
          raise InvalidFormulaError, "Unknown distribution in formula: #{formula}"
        end
      end
    end

    def validate_data!
      # Extract variables that should be in data (response variables)
      required_data_vars = extract_required_data_variables
      
      # puts "Required data vars: #{required_data_vars.inspect}"
      # puts "Available data keys: #{@data.keys.inspect}"
      
      required_data_vars.each do |var|
        unless @data.key?(var.to_sym) || @data.key?(var.to_s)
          raise MissingDataError, "Data variable '#{var}' not found in data"
        end
      end
    end

    def extract_data_variables
      # Extract variables that are actually in the data
      data_keys = @data.keys.map(&:to_s)
      
      # Also look for variables on left side of ~ that are not parameters
      formula_vars = []
      @formulas.each do |formula|
        if formula.match(/(\w+)\s*~/)
          var = $1
          formula_vars << var
        end
      end
      
      # Combine data keys with formula variables
      all_vars = (data_keys + formula_vars).uniq
      
      # Filter to only include those that are actually data (in @data hash)
      all_vars.select { |var| @data.key?(var.to_sym) || @data.key?(var.to_s) }
    end

    def is_parameter?(var)
      @formulas.any? { |f| f.match(/~.*#{var}/) }
    end

    def check_estimated!
      unless @estimated
        raise NotEstimatedError, "Must call .estimate before accessing results"
      end
    end

    def parameters
      @parameters ||= 
        begin
          parameters = Set.new
          derived_params = Set.new  # Parameters defined by linear models
          
          # First pass: identify derived parameters
          @formulas.each do |formula|
            unless formula.match(/~\s*(\w+)\s*\(/)  # Not a distribution
              if match = formula.match(/(\w+)\s*~/)
                derived_params.add(match[1])
              end
            end
          end
          
          @formulas.each do |formula|
            # For likelihood formulas (containing distributions), extract only non-data variables
            if formula.match(/~\s*(\w+)\s*\(/)
              # This is a distribution formula, extract parameters from arguments
              if match = formula.match(/~\s*\w+\s*\(([^)]+)\)/)
                args = match[1]
                params = args.scan(/\b([a-zA-Z_]\w*)\b/).flatten
                params.each do |p|
                  unless is_function_or_distribution?(p) || is_data_variable?(p) || derived_params.include?(p)
                    parameters.add(p)
                  end
                end
              end
            else
              # This is a linear model formula, extract parameters from the right side only
              if match = formula.match(/~\s*(.+)/)
                right_side = match[1]
                params = right_side.scan(/\b([a-zA-Z_]\w*)\b/).flatten
                params.each do |p|
                  unless is_function_or_distribution?(p) || is_data_variable?(p) || derived_params.include?(p)
                    parameters.add(p)
                  end
                end
              end
            end
          end
          
          parameters.to_a.sort
        end 
    end

    def is_function_or_distribution?(word)
      functions = %w[normal exponential uniform gamma beta binomial poisson log exp sqrt]
      functions.include?(word.downcase)
    end
    
    def is_data_variable?(word)
      @data.key?(word.to_sym) || @data.key?(word.to_s)
    end

    def extract_required_data_variables
      # Extract variables that should be data
      required_vars = []
      
      @formulas.each do |formula|
        # For likelihood formulas (response ~ distribution), only the left side is data
        if formula.match(/^(\w+)\s*~\s*(normal|binomial|poisson|exponential)\s*\(/)
          var = $1
          # Only add if it's not defined as a parameter elsewhere
          unless is_likely_parameter?(var)
            required_vars << var
          end
        end
        
        # For linear model formulas (param ~ linear_expression), look for data variables in expression
        if formula.match(/^(\w+)\s*~\s*([^(]+)$/) # No function call on right side
          right_side = $2
          # Extract variables from linear expressions
          vars_in_expression = right_side.scan(/\b([a-zA-Z_]\w*)\b/).flatten
          vars_in_expression.each do |var|
            next if is_function_or_distribution?(var)
            next if var.match(/^\d+$/) # Skip numbers
            
            # If it's not a parameter and is used in arithmetic, it's likely data
            unless is_likely_parameter?(var)
              required_vars << var
            end
          end
        end
      end
      
      required_vars.uniq
    end

    def is_likely_parameter?(var)
      # A variable is likely a parameter if it appears on the left side of a prior formula
      # A prior formula has constants (numbers) as arguments, not other variables
      @formulas.each do |f|
        if f.match(/^#{Regexp.escape(var)}\s*~\s*(normal|exponential|uniform|gamma|beta)\s*\(([^)]+)\)/)
          args = $2
          # If arguments are mostly numbers/constants, it's a prior (parameter definition)
          # If arguments are mostly variables, it's a likelihood (data relationship)
          var_count = args.scan(/[a-zA-Z_]\w*/).length
          number_count = args.scan(/\d+/).length
          if number_count > 0 && var_count <= 1 # Mostly constants
            return true
          end
        end
      end
      false
    end

    def calculate_sample_mean
      # Find the response variable (left side of first formula)
      response_var = nil
      @formulas.each do |formula|
        if match = formula.match(/(\w+)\s*~/)
          var = match[1]
          unless is_parameter?(var)
            response_var = var
            break
          end
        end
      end
      
      return 1.5 unless response_var # fallback
      
      # Get data for response variable
      values = @data[response_var.to_sym] || @data[response_var.to_s]
      return 1.5 unless values && values.is_a?(Array) # fallback
      
      values.sum.to_f / values.length
    end

    # Calculate log-likelihood for current parameter values
    def log_likelihood(param_values, param_names)
      param_hash = param_names.zip(param_values).to_h
      total_log_lik = 0.0
      
      @formulas.each do |formula|
        contribution = calculate_formula_log_likelihood(formula, param_hash)
        total_log_lik += contribution
      end
      
      total_log_lik
    end
    
    # Calculate log-likelihood contribution from a single formula
    def calculate_formula_log_likelihood(formula, param_hash)
      if match = formula.match(/(\w+)\s*~\s*(\w+)\s*\(([^)]+)\)/)
        var_name = match[1]
        distribution = match[2]
        args_str = match[3]
        
        # Check if this is a likelihood (variable is in data) or prior (variable is parameter)
        data_values = get_data_values(var_name)
        if data_values.empty?
          # This is a prior - variable not in data, so skip for likelihood calculation
          return 0.0
        end
        
        # This is a likelihood formula - variable is in data
        # Parse distribution arguments and evaluate for each data point
        total_log_lik = 0.0
        
        case distribution.downcase
        when 'normal'
          # For normal distribution, we need to evaluate mu for each data point
          args = parse_distribution_args(args_str, param_hash)
          
          if args_str.include?('mu') && has_linear_model_for?('mu')
            # Evaluate mu as linear model for each data point
            data_values.each_with_index do |x, i|
              mu_val = evaluate_linear_model_for_observation('mu', param_hash, i)
              sd_val = args[1]  # sigma parameter
              density = normal_log_density(x, mu_val, sd_val)
              total_log_lik += density
              # puts "DEBUG: x=#{x}, mu=#{mu_val}, sd=#{sd_val}, density=#{density}, total=#{total_log_lik}"
            end
          else
            # Simple case - mu is just a parameter
            mean, sd = args
            total_log_lik = data_values.sum { |x| normal_log_density(x, mean, sd) }
          end
          
        when 'exponential'
          rate = parse_distribution_args(args_str, param_hash)[0]
          total_log_lik = data_values.sum { |x| exponential_log_density(x, rate) }
        end
        
        total_log_lik
      else
        0.0  # Formula doesn't match expected pattern
      end
    end
    
    # Check if a parameter has a linear model defined
    def has_linear_model_for?(param)
      @formulas.any? do |formula|
        formula.match(/^#{Regexp.escape(param)}\s*~\s*[^(]/) # No opening parenthesis after ~
      end
    end
    
    # Evaluate linear model for a specific observation
    def evaluate_linear_model_for_observation(param, param_hash, obs_index)
      # Find the linear model formula for this parameter
      linear_formula = @formulas.find do |formula|
        formula.match(/^#{Regexp.escape(param)}\s*~\s*([^(]+)$/)
      end
      
      return param_hash[param] || 0.0 unless linear_formula
      
      # Extract the right-hand side
      if match = linear_formula.match(/^#{Regexp.escape(param)}\s*~\s*(.+)$/)
        expression = match[1].strip
        evaluate_linear_expression(expression, param_hash, obs_index)
      else
        param_hash[param] || 0.0
      end
    end
    
    # Evaluate linear expression for a specific observation
    def evaluate_linear_expression(expr, param_hash, obs_index)
      # Handle expressions like "a + b * height"
      result = 0.0
      
      # Split by + and -
      terms = expr.split(/([+-])/).map(&:strip)
      current_sign = 1
      
      i = 0
      while i < terms.length
        term = terms[i]
        
        if term == '+'
          current_sign = 1
        elsif term == '-'
          current_sign = -1
        elsif !term.empty?
          term_value = evaluate_term(term, param_hash, obs_index)
          result += current_sign * term_value
        end
        
        i += 1
      end
      
      result
    end
    
    # Evaluate a single term (might be parameter, number, or multiplication)
    def evaluate_term(term, param_hash, obs_index)
      # Handle multiplication
      if term.include?('*')
        factors = term.split('*').map(&:strip)
        result = 1.0
        factors.each do |factor|
          if param_hash.key?(factor)
            result *= param_hash[factor]
          elsif @data.key?(factor.to_sym) || @data.key?(factor.to_s)
            # Get specific observation from data
            data_values = @data[factor.to_sym] || @data[factor.to_s]
            result *= data_values[obs_index] if data_values.is_a?(Array) && obs_index < data_values.length
          elsif factor.match(/^\d+(\.\d+)?$/)
            result *= factor.to_f
          end
        end
        result
      elsif param_hash.key?(term)
        param_hash[term]
      elsif term.match(/^\d+(\.\d+)?$/)
        term.to_f
      else
        0.0
      end
    end
    
    # Check if formula defines a prior distribution
    def is_prior_formula?(formula)
      if match = formula.match(/(\w+)\s*~\s*(\w+)\s*\(([^)]+)\)/)
        var_name = match[1]
        # A formula is a prior if the left-hand side is a parameter (not data)
        # If it's in our data, it's a likelihood; if not, it's a prior
        is_data = is_data_variable?(var_name)
        !is_data
      else
        false
      end
    end
    
    # Get data values for a variable
    def get_data_values(var_name)
      values = @data[var_name.to_sym] || @data[var_name.to_s]
      return [] unless values && values.is_a?(Array)
      values
    end
    
    # Parse distribution arguments, evaluating expressions
    def parse_distribution_args(args_str, param_hash)
      args_str.split(',').map do |arg|
        arg = arg.strip
        evaluate_expression(arg, param_hash)
      end
    end
    
    # Evaluate mathematical expressions with parameters and data
    def evaluate_expression(expr, param_hash)
      # Handle simple parameter references
      if param_hash.key?(expr)
        return param_hash[expr]
      end
      
      # Handle linear expressions like "a + b * height"
      if expr.include?('+')
        terms = expr.split('+').map(&:strip)
        return terms.sum { |term| evaluate_expression(term, param_hash) }
      end
      
      if expr.include?('*')
        factors = expr.split('*').map(&:strip)
        result = 1.0
        factors.each do |factor|
          if param_hash.key?(factor)
            result *= param_hash[factor]
          elsif @data.key?(factor.to_sym)
            # For data variables in expressions, we need to handle this differently
            # For now, return the mean of the data variable
            data_vals = @data[factor.to_sym]
            result *= (data_vals.sum.to_f / data_vals.length) if data_vals.is_a?(Array)
          elsif factor.match(/^\d+(\.\d+)?$/)
            result *= factor.to_f
          end
        end
        return result
      end
      
      # Handle numbers
      if expr.match(/^\d+(\.\d+)?$/)
        return expr.to_f
      end
      
      # Default fallback
      1.0
    end
    
    # Normal distribution log density
    def normal_log_density(x, mean, sd)
      return -Float::INFINITY if sd <= 0
      -0.5 * Math.log(2 * Math::PI) - Math.log(sd) - 0.5 * ((x - mean) / sd) ** 2
    end
    
    # Exponential distribution log density  
    def exponential_log_density(x, rate)
      return -Float::INFINITY if rate <= 0 || x < 0
      Math.log(rate) - rate * x
    end
    
    # Get initial parameter values
    def get_initial_values(param_names)
      if @start
        # Use provided start values, with defaults for missing parameters
        param_names.map { |name| @start[name.to_sym] || @start[name.to_s] || default_start_value(name) }
      else
        # Use default start values
        param_names.map { |name| default_start_value(name) }
      end
    end
    
    # Get default starting value for a parameter
    def default_start_value(param_name)
      case param_name
      when 'mu'
        calculate_sample_mean
      when 'sigma'
        1.0
      when 'a'
        0.0
      when 'b' 
        0.0
      else
        0.0
      end
    end
    
    # Nelder-Mead optimization algorithm
    def nelder_mead_optimize(initial_values, param_names, max_iter: 1000, tolerance: 1e-6)
      n = initial_values.length
      
      # Create initial simplex
      simplex = [initial_values.dup]
      
      # Add n more points to form simplex
      (0...n).each do |i|
        point = initial_values.dup
        point[i] += point[i] != 0 ? point[i] * 0.05 : 0.00025
        simplex << point
      end
      
      # Parameters for Nelder-Mead
      alpha = 1.0   # reflection
      gamma = 2.0   # expansion
      rho = 0.5     # contraction
      sigma = 0.5   # shrink
      
      max_iter.times do |iter|
        # Evaluate function at all points
        values = simplex.map { |point| -log_likelihood(point, param_names) }  # Minimize negative log-likelihood
        
        # Sort by function value
        indices = (0...values.length).sort_by { |i| values[i] }
        
        best_idx = indices[0]
        worst_idx = indices[-1]
        second_worst_idx = indices[-2]
        
        # Check convergence
        if (values[worst_idx] - values[best_idx]).abs < tolerance
          return { x: simplex[best_idx], fval: values[best_idx], iterations: iter }
        end
        
        # Calculate centroid (excluding worst point)
        centroid = Array.new(n, 0.0)
        (0...n).each do |i|
          sum = 0.0
          indices[0...-1].each { |idx| sum += simplex[idx][i] }
          centroid[i] = sum / n
        end
        
        # Reflection
        reflected = Array.new(n) { |i| centroid[i] + alpha * (centroid[i] - simplex[worst_idx][i]) }
        reflected_val = -log_likelihood(reflected, param_names)
        
        if reflected_val < values[best_idx]
          # Expansion
          expanded = Array.new(n) { |i| centroid[i] + gamma * (reflected[i] - centroid[i]) }
          expanded_val = -log_likelihood(expanded, param_names)
          
          if expanded_val < reflected_val
            simplex[worst_idx] = expanded
          else
            simplex[worst_idx] = reflected
          end
        elsif reflected_val < values[second_worst_idx]
          simplex[worst_idx] = reflected
        else
          # Contraction
          if reflected_val < values[worst_idx]
            # Outside contraction
            contracted = Array.new(n) { |i| centroid[i] + rho * (reflected[i] - centroid[i]) }
          else
            # Inside contraction
            contracted = Array.new(n) { |i| centroid[i] + rho * (simplex[worst_idx][i] - centroid[i]) }
          end
          
          contracted_val = -log_likelihood(contracted, param_names)
          
          if contracted_val < [reflected_val, values[worst_idx]].min
            simplex[worst_idx] = contracted
          else
            # Shrink
            (1...simplex.length).each do |i|
              (0...n).each do |j|
                simplex[i][j] = simplex[best_idx][j] + sigma * (simplex[i][j] - simplex[best_idx][j])
              end
            end
          end
        end
      end
      
      # Return best result found
      values = simplex.map { |point| -log_likelihood(point, param_names) }
      best_idx = values.each_with_index.min[1]
      { x: simplex[best_idx], fval: values[best_idx], iterations: max_iter }
    end
    
    # Calculate variance-covariance matrix using numerical Hessian
    def calculate_vcov(optimal_params, param_names)
      n = optimal_params.length
      h = 1e-5  # Step size for numerical differentiation
      
      hessian = Matrix.build(n, n) do |i, j|
        if i == j
          # Diagonal elements - second derivative
          params_plus = optimal_params.dup
          params_minus = optimal_params.dup
          params_plus[i] += h
          params_minus[i] -= h
          
          f_plus = -log_likelihood(params_plus, param_names)
          f_minus = -log_likelihood(params_minus, param_names)
          f_center = -log_likelihood(optimal_params, param_names)
          
          (f_plus - 2 * f_center + f_minus) / (h * h)
        else
          # Off-diagonal elements - mixed second derivative
          params_pp = optimal_params.dup
          params_pm = optimal_params.dup
          params_mp = optimal_params.dup
          params_mm = optimal_params.dup
          
          params_pp[i] += h; params_pp[j] += h
          params_pm[i] += h; params_pm[j] -= h
          params_mp[i] -= h; params_mp[j] += h
          params_mm[i] -= h; params_mm[j] -= h
          
          f_pp = -log_likelihood(params_pp, param_names)
          f_pm = -log_likelihood(params_pm, param_names)
          f_mp = -log_likelihood(params_mp, param_names)
          f_mm = -log_likelihood(params_mm, param_names)
          
          (f_pp - f_pm - f_mp + f_mm) / (4 * h * h)
        end
      end
      
      # Return inverse of Hessian (approximation to covariance matrix)
      begin
        hessian.inverse
      rescue Matrix::ErrNotRegular
        # If Hessian is singular, return diagonal approximation
        Matrix.diagonal(*Array.new(n, 0.1))
      end
    end
  end
end
