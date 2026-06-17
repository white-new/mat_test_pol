function out = iif(cond, t, f)
    % IIF - Условный оператор (тернарный)
    %
    %   out = iif(cond, t, f)
    %
    %   Если cond == true, out = t, иначе out = f
    %
    %   Пример:
    %       result = iif(x > 0, 'positive', 'negative');

    if cond
        out = t;
    else
        out = f;
    end
end