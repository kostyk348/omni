(vl-load-com)

;;; ---------------------------------------------------------
;;; 1. OMNI-NOTE (Пространственный маркер-комментарий)
;;; ---------------------------------------------------------
(defun c:OMNI-NOTE ( / pt msg oldLayer )
  (setq pt (getpoint "\n[OMNI] Укажи точку для комментария: "))
  (setq msg (getstring T "\n[OMNI] Введи текст: "))
  (setq oldLayer (getvar "CLAYER"))
  (command "-layer" "m" "OMNI_NOTES" "c" "1" "" "p" "n" "" "")
  (command "circle" pt 50) ; Радиус кружка (настрой под свой масштаб)
  (command "text" pt 25 0 msg) ; Высота текста
  (setvar "CLAYER" oldLayer)
  (princ "\n[OMNI] Зафиксировано.")
  (princ)
)

;;; ---------------------------------------------------------
;;; 2. OMNI-SNAP (Слепок с АВТОГРАФОМ АВТОРА)
;;; ---------------------------------------------------------
(defun c:OMNI-SNAP ( / msg dwgPath dwgName dateStr userName omniDir backupPath ms )
  (setq msg (getstring T "\n[OMNI] Описание изменения (или Enter): "))
  (command "_QSAVE")
  
  (setq dwgPath (getvar "DWGPREFIX"))
  (setq dwgName (getvar "DWGNAME"))
  (setq dateStr (rtos (getvar "CDATE") 2 6)) ; дата+время
  (setq dateStr (vl-string-subst "-" "." dateStr)) ; точка -> дефис (имя файла)
  (setq ms (itoa (rem (getvar "MILLISECS") 1000))) ; миллисекунды против коллизий
  (setq userName (getvar "LOGINNAME"))       ; имя пользователя WINDOWS
  
  (setq omniDir (strcat dwgPath "_OMNI_HISTORY\\"))
  (vl-mkdir omniDir)
  
  ;; имя: дата_время_мс_пользователь_описание_файл.dwg
  (setq backupPath (strcat omniDir dateStr "_" ms "_" userName "_" msg "_" dwgName))
  (vl-file-copy (strcat dwgPath dwgName) backupPath)
  
  (princ (strcat "\n[OMNI] Снимок сохранён: " backupPath))
  (princ)
)

;;; ---------------------------------------------------------
;;; 3. OMNI-LOG (Машина времени - Открыть старую версию)
;;; ---------------------------------------------------------
(defun c:OMNI-LOG ( / dwgPath omniDir fileList i fileToOpen num acadObj docs)
  (setq dwgPath (getvar "DWGPREFIX"))
  (setq omniDir (strcat dwgPath "_OMNI_HISTORY\\"))
  (setq fileList (vl-directory-files omniDir "*.dwg" 1))
  
  (if (not fileList)
    (princ "\n[OMNI] История пуста. Сделай первый OMNI-SNAP.")
    (progn
      (princ "\n--- ИСТОРИЯ OMNI ---")
      (setq i 0)
      (foreach file fileList
        (setq i (1+ i))
        (princ (strcat "\n[" (itoa i) "] " file))
      )
      (princ "\n--------------------")
      (setq num (getint "\n[OMNI] Введи номер слепка для открытия (0 - отмена): "))
      (if (and num (> num 0) (<= num (length fileList)))
        (progn
          (setq fileToOpen (strcat omniDir (nth (1- num) fileList)))
          (princ (strcat "\n[OMNI] Открываю: " fileToOpen))
          (setq acadObj (vlax-get-acad-object))
          (setq docs (vla-get-documents acadObj))
          (vla-open docs fileToOpen) ; Открывает в новой вкладке
        )
      )
    )
  )
  (princ)
)


;;; ---------------------------------------------------------
;;; 4. OMNI-DIFF (Наложение) - БЕСШУМНЫЙ ZERO-CLICK
;;; ---------------------------------------------------------
(defun c:OMNI-DIFF ( / dwgPath omniDir fileList i fileToOpen num oldFiledia oldOsmode )
  (setq dwgPath (getvar "DWGPREFIX"))
  (setq omniDir (strcat dwgPath "_OMNI_HISTORY\\"))
  (setq fileList (vl-directory-files omniDir "*.dwg" 1))
  
  (if (not fileList)
    (princ "\n[OMNI] История пуста.")
    (progn
      (princ "\n--- ВЫБОР ДЛЯ СРАВНЕНИЯ ---")
      (setq i 0)
      (foreach file fileList
        (setq i (1+ i))
        (princ (strcat "\n[" (itoa i) "] " file))
      )
      (setq num (getint "\n[OMNI] Какой слепок наложить фоном? (0 - отмена): "))
      
      (if (and num (> num 0) (<= num (length fileList)))
        (progn
          (setq fileToOpen (strcat omniDir (nth (1- num) fileList)))
          
          ;; Сохраняем и отключаем привязки и диалоги
          (setq oldFiledia (getvar "FILEDIA"))
          (setq oldOsmode (getvar "OSMODE"))
          (setvar "FILEDIA" 0)
          (setvar "OSMODE" 0)
          
          ;; 1. Подгружаем старый чертеж как XREF (Наложение).
          ;; '(0 0 0) - список координат, который железобетонно читается в любой версии AutoCAD
          (command "_.-XREF" "_O" fileToOpen '(0 0 0) 1 1 0)
          
          ;; 2. Перекрашиваем ВСЕ слои подгруженного чертежа в КРАСНЫЙ (цвет 1).
          ;; *|* - означает "все слои всех внешних ссылок"
          (command "_.-LAYER" "_C" "1" "*|*" "")
          
          ;; Возвращаем привязки и диалоги
          (setvar "OSMODE" oldOsmode)
          (setvar "FILEDIA" oldFiledia)
          
          (command "_.REGENALL")
          (princ "\n[OMNI] Старая версия наложена. Для отмены введи OMNI-CLEAR")
        )
      )
    )
  )
  (princ)
)

;;; ---------------------------------------------------------
;;; 5. OMNI-CLEAR (снятие наложения) - удаляет ТОЛЬКО наши XREF
;;; ---------------------------------------------------------
(defun c:OMNI-CLEAR ( / oldFiledia doc blocks blk blkName dwgBase )
  (setq doc (vla-get-ActiveDocument (vlax-get-acad-object)))
  (setq dwgBase (vl-string-left-trim "*" (vl-string-right-trim ".dwg" (getvar "DWGNAME"))))
  
  (setq oldFiledia (getvar "FILEDIA"))
  (setvar "FILEDIA" 0)
  
  ;; проходим по блокам, удаляем только xref-ы с нашим суффиксом
  (setq blocks (vla-get-Blocks doc))
  (vlax-for blk blocks
    (if (= (vla-get-IsXref blk) :vlax-true)
      (progn
        (setq blkName (vla-get-Name blk))
        ;; наши бэкапы: <дата>_<мс>_<пользователь>_<описание>_<DWGNAME>
        (if (vl-string-search (strcat "_" dwgBase) blkName)
          (progn
            (command "_.-XREF" "_D" blkName)
            (princ (strcat "\n[OMNI] Удалён XREF: " blkName))
          )
        )
      )
    )
  )
  
  (setvar "FILEDIA" oldFiledia)
  (princ "\n[OMNI] Наложение снято.")
  (princ)
)


;;; ---------------------------------------------------------
;;; 6. OMNI-TOGGLE (Быстрое вкл/выкл красной подложки)
;;; Слои XREF называются "<имя_xref>|<имя_слоя>" — переключаем все с "|".
;;; ---------------------------------------------------------
(defun c:OMNI-TOGGLE ( / layers lay layName curState found )
  (vl-load-com)
  (setq layers (vla-get-Layers (vla-get-ActiveDocument (vlax-get-acad-object)))
        curState nil found nil)
  ;; если хоть один слой наложения включён — выключаем все; иначе включаем
  (vlax-for lay layers
    (if (vl-string-search "|" (vla-get-Name lay))
      (progn
        (setq found T)
        (if (= (vla-get-LayerOn lay) :vlax-true) (setq curState T))
      )
    )
  )
  (if (not found)
    (princ "\n[OMNI] Наложение не найдено. Сначала запусти OMNI-DIFF.")
    (progn
      (vlax-for lay layers
        (if (vl-string-search "|" (vla-get-Name lay))
          (if curState
            (vla-put-LayerOn lay :vlax-false)
            (vla-put-LayerOn lay :vlax-true)
          )
        )
      )
      (command "_.REGENALL")
      (if curState
        (princ "\n[OMNI] Слои наложения скрыты.")
        (princ "\n[OMNI] Слои наложения показаны.")
      )
    )
  )
  (princ)
)

(princ "\n[OMNI v0.4]. Команды: OMNI-SNAP (Слепок), OMNI-LOG (Открыть), OMNI-DIFF (Сравнить), OMNI-CLEAR (Очистить), OMNI-TOGGLE (Показ/скрытие), OMNI-NOTE (Коммент).")
(princ)