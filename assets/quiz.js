// 测验组件：给 .quiz 里的 .q 绑定即时反馈。
// 结构约定：<div class="q" data-answer="索引" data-why="解释">，选项为 <button class="opt">。
// 无脚本时选项仍可点击，只是没有反馈；打印时 course.css 会把解释展开。

(function () {
  'use strict';

  function initQuiz(quiz) {
    var questions = Array.prototype.slice.call(quiz.querySelectorAll('.q'));
    var scoreEl = quiz.querySelector('.score');
    var resetBtn = quiz.querySelector('.reset');
    var answered = 0;
    var correct = 0;

    function updateScore() {
      if (!scoreEl) return;
      scoreEl.textContent = '已答 ' + answered + ' / ' + questions.length +
        (answered ? '，答对 ' + correct : '');
    }

    questions.forEach(function (q) {
      var answer = Number(q.dataset.answer);
      var why = q.querySelector('.why');
      var opts = Array.prototype.slice.call(q.querySelectorAll('.opt'));

      opts.forEach(function (opt, index) {
        opt.addEventListener('click', function () {
          if (q.dataset.done) return;
          q.dataset.done = '1';
          answered += 1;

          if (index === answer) {
            correct += 1;
            opt.classList.add('correct');
          } else {
            opt.classList.add('wrong');
            if (opts[answer]) opts[answer].classList.add('correct');
          }

          opts.forEach(function (o) { o.disabled = true; });
          if (why) why.hidden = false;
          updateScore();
        });
      });
    });

    if (resetBtn) {
      resetBtn.addEventListener('click', function () {
        answered = 0;
        correct = 0;
        questions.forEach(function (q) {
          delete q.dataset.done;
          Array.prototype.forEach.call(q.querySelectorAll('.opt'), function (o) {
            o.disabled = false;
            o.classList.remove('correct', 'wrong');
          });
          var why = q.querySelector('.why');
          if (why) why.hidden = true;
        });
        updateScore();
        if (quiz.scrollIntoView) {
          quiz.scrollIntoView({ block: 'start', behavior: 'smooth' });
        }
      });
    }

    updateScore();
  }

  function boot() {
    Array.prototype.forEach.call(document.querySelectorAll('.quiz'), initQuiz);
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', boot);
  } else {
    boot();
  }
})();
