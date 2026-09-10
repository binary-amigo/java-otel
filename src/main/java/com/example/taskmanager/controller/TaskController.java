package com.example.taskmanager.controller;

import com.example.taskmanager.model.Task;
import com.example.taskmanager.service.TaskService;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.stereotype.Controller;
import org.springframework.ui.Model;
import org.springframework.web.bind.annotation.*;

@Controller
@RequestMapping("/tasks")
public class TaskController {

    @Autowired
    private TaskService taskService;

    // Web page mappings
    @GetMapping
    public String listTasks(Model model) {
        model.addAttribute("tasks", taskService.getAllTasks());
        model.addAttribute("newTask", new Task());
        return "tasks";
    }

    @GetMapping("/new")
    public String showCreateForm(Model model) {
        model.addAttribute("task", new Task());
        return "task-form";
    }

    @GetMapping("/edit/{id}")
    public String showEditForm(@PathVariable Long id, Model model) {
        Task task = taskService.getTaskById(id)
                .orElseThrow(() -> new RuntimeException("Task not found with id: " + id));
        model.addAttribute("task", task);
        return "task-form";
    }

    // REST API endpoints
    @PostMapping("/api")
    @ResponseBody
    public Task createTask(@RequestBody Task task) {
        return taskService.createTask(task);
    }

    @GetMapping("/api")
    @ResponseBody
    public java.util.List<Task> getAllTasks(@RequestParam(defaultValue = "false") boolean fail) {
        if (fail) {
            throw new RuntimeException("Intentional task list failure");
        }
        return taskService.getAllTasks();
    }

    @GetMapping("/api/{id}")
    @ResponseBody
    public Task getTaskById(@PathVariable Long id) {
        return taskService.getTaskById(id)
                .orElseThrow(() -> new RuntimeException("Task not found with id: " + id));
    }

    @PutMapping("/api/{id}")
    @ResponseBody
    public Task updateTask(@PathVariable Long id, @RequestBody Task task) {
        return taskService.updateTask(id, task);
    }

    @DeleteMapping("/api/{id}")
    @ResponseBody
    public void deleteTask(@PathVariable Long id) {
        taskService.deleteTask(id);
    }

    // Form submissions
    @PostMapping
    public String createTaskFromForm(@ModelAttribute Task task) {
        taskService.createTask(task);
        return "redirect:/tasks";
    }

    @PostMapping("/{id}")
    public String updateTaskFromForm(@PathVariable Long id, @ModelAttribute Task task) {
        taskService.updateTask(id, task);
        return "redirect:/tasks";
    }

    @PostMapping("/delete/{id}")
    public String deleteTaskFromForm(@PathVariable Long id) {
        taskService.deleteTask(id);
        return "redirect:/tasks";
    }

    @GetMapping("/api/test/slow-db-read")
    @ResponseBody
    public java.util.Map<String, Object> triggerSlowDbRead(
            @RequestParam(defaultValue = "1200") long delayMs,
            @RequestParam(defaultValue = "600") long dbDelayMs) {
        long normalizedDelayMs = normalizeSlowDelayMs(delayMs);
        long normalizedDbDelayMs = normalizeSlowDbDelayMs(dbDelayMs, normalizedDelayMs);
        long count = taskService.runSlowReadQuery(normalizedDelayMs, normalizedDbDelayMs);
        return java.util.Map.of(
                "type", "slow-db-read",
                "delayMs", normalizedDelayMs,
                "dbDelayMs", normalizedDbDelayMs,
                "taskCount", count);
    }

    @GetMapping("/api/test/slow-db-write")
    @ResponseBody
    public java.util.Map<String, Object> triggerSlowDbWrite(
            @RequestParam(defaultValue = "1200") long delayMs,
            @RequestParam(defaultValue = "600") long dbDelayMs) {
        long normalizedDelayMs = normalizeSlowDelayMs(delayMs);
        long normalizedDbDelayMs = normalizeSlowDbDelayMs(dbDelayMs, normalizedDelayMs);
        long count = taskService.runSlowWriteQuery(normalizedDelayMs, normalizedDbDelayMs);
        return java.util.Map.of(
                "type", "slow-db-write",
                "delayMs", normalizedDelayMs,
                "dbDelayMs", normalizedDbDelayMs,
                "taskCount", count);
    }

    // Endpoint to trigger a bad SQL query for testing error collection
    @GetMapping("/api/test/bad-query")
    @ResponseBody
    public String triggerBadQuery(@RequestParam(defaultValue = "true") boolean fail) {
        if (fail) {
            taskService.triggerBadQuery();
            return "Query executed successfully";
        }
        return "Bad query skipped";
    }

    private long normalizeSlowDelayMs(long delayMs) {
        return Math.max(1100, Math.min(delayMs, 10000));
    }

    private long normalizeSlowDbDelayMs(long dbDelayMs, long delayMs) {
        return Math.max(600, Math.min(dbDelayMs, delayMs));
    }
}
