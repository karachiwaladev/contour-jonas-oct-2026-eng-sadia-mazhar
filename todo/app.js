const DB_NAME = 'todo-app';
const STORE = 'tasks';
const DB_VERSION = 3;

function openDb() {
  return new Promise((resolve, reject) => {
    const req = indexedDB.open(DB_NAME, DB_VERSION);
    req.onerror = () => reject(req.error);
    req.onsuccess = () => {
      // Let a newer tab upgrade the schema instead of being blocked by this one.
      req.result.onversionchange = () => {
        req.result.close();
        location.reload();
      };
      resolve(req.result);
    };
    req.onupgradeneeded = (e) => {
      const db = e.target.result;
      if (!db.objectStoreNames.contains(STORE)) {
        db.createObjectStore(STORE, { keyPath: 'id', autoIncrement: true });
      }
    };
  });
}

function normalizeTask(raw) {
  return {
    id: raw.id,
    text: raw.text,
    done: Boolean(raw.done),
    createdAt: raw.createdAt ?? Date.now(),
    dueDate: raw.dueDate ?? null,
    tags: Array.isArray(raw.tags) ? raw.tags : [],
    recurrence: raw.recurrence === 'daily' ? 'daily' : null,
    repeatUntil: raw.repeatUntil ?? null,
    spawned: Boolean(raw.spawned),
  };
}

function todayIso() {
  const d = new Date();
  const mm = String(d.getMonth() + 1).padStart(2, '0');
  const dd = String(d.getDate()).padStart(2, '0');
  return `${d.getFullYear()}-${mm}-${dd}`;
}

function addDaysIso(iso, days) {
  const [y, m, d] = iso.split('-').map(Number);
  const next = new Date(y, m - 1, d + days);
  const mm = String(next.getMonth() + 1).padStart(2, '0');
  const dd = String(next.getDate()).padStart(2, '0');
  return `${next.getFullYear()}-${mm}-${dd}`;
}

// Creates the next daily occurrence once, when a recurring task is completed.
async function spawnNextOccurrence(database, task) {
  if (task.recurrence !== 'daily' || !task.dueDate || task.spawned) return;
  const nextDue = addDaysIso(task.dueDate, 1);
  if (task.repeatUntil && nextDue > task.repeatUntil) return;
  await addTask(database, {
    text: task.text,
    dueDate: nextDue,
    tags: task.tags,
    recurrence: task.recurrence,
    repeatUntil: task.repeatUntil,
  });
  task.spawned = true;
}

function parseTags(input) {
  return input
    .split(',')
    .map((t) => t.trim())
    .filter(Boolean);
}

async function getAllTasks(db) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, 'readonly');
    const store = tx.objectStore(STORE);
    const req = store.getAll();
    req.onerror = () => reject(req.error);
    req.onsuccess = () => resolve((req.result || []).map(normalizeTask));
  });
}

async function addTask(db, { text, dueDate, tags, recurrence = null, repeatUntil = null, createdAt = Date.now() }) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, 'readwrite');
    const store = tx.objectStore(STORE);
    const req = store.add({
      text,
      done: false,
      createdAt,
      dueDate: dueDate || null,
      tags,
      recurrence,
      repeatUntil,
      spawned: false,
    });
    req.onerror = () => reject(req.error);
    req.onsuccess = () => resolve(req.result);
  });
}

async function updateTask(db, task) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, 'readwrite');
    const store = tx.objectStore(STORE);
    const req = store.put(task);
    req.onerror = () => reject(req.error);
    req.onsuccess = () => resolve();
  });
}

async function deleteTask(db, id) {
  return new Promise((resolve, reject) => {
    const tx = db.transaction(STORE, 'readwrite');
    const store = tx.objectStore(STORE);
    const req = store.delete(id);
    req.onerror = () => reject(req.error);
    req.onsuccess = () => resolve();
  });
}

const listEl = document.getElementById('task-list');
const formEl = document.getElementById('add-form');
const inputEl = document.getElementById('task-input');
const dueEl = document.getElementById('due-input');
const tagsEl = document.getElementById('tags-input');
const repeatEl = document.getElementById('repeat-input');
const untilEl = document.getElementById('until-input');
const errorEl = document.getElementById('form-error');
const statusFilterEl = document.getElementById('status-filter');
const tagFilterEl = document.getElementById('tag-filter');

let db;

function collectTags(tasks) {
  const set = new Set();
  for (const t of tasks) {
    for (const tag of t.tags) set.add(tag);
  }
  return [...set].sort((a, b) => a.localeCompare(b));
}

function applyFilters(tasks) {
  const status = statusFilterEl.value;
  const tag = tagFilterEl.value;
  return tasks.filter((task) => {
    if (status === 'active' && task.done) return false;
    if (status === 'complete' && !task.done) return false;
    if (tag && !task.tags.includes(tag)) return false;
    return true;
  });
}

function renderTagFilterOptions(allTags, selected) {
  const current = tagFilterEl.value;
  tagFilterEl.innerHTML = '<option value="">All tags</option>';
  for (const tag of allTags) {
    const opt = document.createElement('option');
    opt.value = tag;
    opt.textContent = tag;
    if (tag === selected || tag === current) opt.selected = true;
    tagFilterEl.appendChild(opt);
  }
}

function render(tasks, allTags) {
  renderTagFilterOptions(allTags, tagFilterEl.value);
  const visible = applyFilters(tasks);
  visible.sort((a, b) => a.createdAt - b.createdAt);
  listEl.innerHTML = '';
  for (const task of visible) {
    const li = document.createElement('li');
    li.className = 'task-item' + (task.done ? ' done' : '');
    li.dataset.id = String(task.id);

    const main = document.createElement('div');
    main.className = 'task-main';

    const label = document.createElement('span');
    label.className = 'task-text';
    label.textContent = task.text;

    const meta = document.createElement('div');
    meta.className = 'task-meta';
    if (task.dueDate) {
      const due = document.createElement('span');
      const overdue = !task.done && task.dueDate < todayIso();
      due.className = 'due' + (overdue ? ' overdue' : '');
      due.textContent = overdue ? `Overdue: ${task.dueDate}` : `Due: ${task.dueDate}`;
      meta.appendChild(due);
      if (overdue) li.classList.add('is-overdue');
    }
    if (task.recurrence === 'daily') {
      const rep = document.createElement('span');
      rep.className = 'repeat';
      rep.textContent = task.repeatUntil ? `Repeats daily until ${task.repeatUntil}` : 'Repeats daily';
      meta.appendChild(rep);
    }
    if (task.tags.length) {
      const tagsWrap = document.createElement('span');
      tagsWrap.className = 'tags';
      tagsWrap.textContent = task.tags.map((t) => `#${t}`).join(' ');
      meta.appendChild(tagsWrap);
    }

    main.append(label, meta);

    const toggleBtn = document.createElement('button');
    toggleBtn.type = 'button';
    toggleBtn.textContent = task.done ? 'Undo' : 'Done';
    toggleBtn.addEventListener('click', async () => {
      task.done = !task.done;
      if (task.done) await spawnNextOccurrence(db, task);
      await updateTask(db, task);
      await refresh();
    });

    const deleteBtn = document.createElement('button');
    deleteBtn.type = 'button';
    deleteBtn.className = 'delete';
    deleteBtn.textContent = 'Delete';
    deleteBtn.addEventListener('click', async () => {
      await deleteTask(db, task.id);
      await refresh();
    });

    li.append(main, toggleBtn, deleteBtn);
    listEl.appendChild(li);
  }
}

async function refresh() {
  const tasks = await getAllTasks(db);
  render(tasks, collectTags(tasks));
}

formEl.addEventListener('submit', async (e) => {
  e.preventDefault();
  const text = inputEl.value.trim();
  if (!text) return;
  const repeat = repeatEl.checked;
  const repeatUntil = untilEl.value || null;
  errorEl.textContent = '';
  if (repeat && !dueEl.value) {
    errorEl.textContent = 'A due date is required for a repeating task.';
    return;
  }
  if (repeat && repeatUntil && repeatUntil < dueEl.value) {
    errorEl.textContent = 'Repeat-until date cannot be before the due date.';
    return;
  }
  await addTask(db, {
    text,
    dueDate: dueEl.value || null,
    tags: parseTags(tagsEl.value),
    recurrence: repeat ? 'daily' : null,
    repeatUntil: repeat ? repeatUntil : null,
  });
  inputEl.value = '';
  dueEl.value = '';
  tagsEl.value = '';
  repeatEl.checked = false;
  untilEl.value = '';
  untilEl.disabled = true;
  await refresh();
});

repeatEl.addEventListener('change', () => {
  untilEl.disabled = !repeatEl.checked;
  if (!repeatEl.checked) untilEl.value = '';
});
statusFilterEl.addEventListener('change', () => refresh());
tagFilterEl.addEventListener('change', () => refresh());

openDb().then(async (database) => {
  db = database;
  await refresh();
});
